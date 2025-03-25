//===-- SNITCHAutoFrep.cpp - Automatically insert frep for repeating FP insts ---------===//
//
// ???
//
//===----------------------------------------------------------------------===//
//
// FIXME: combine this with the SNITCHFrepLoop.cpp pass + extend that one to allow
// for the PseudoLoadMove and PsuedoStoreMove pseudo insts. Might need to make two
// passes one pre RA and one post RA.
//
// This pass looks for repeating fp insts and then tries to find a reduction operation.
// If it finds one it will try to use freps stagger. If these can both be applied, the
// pass will calculate what stagger amount is best and then insert a frep inst with it 
// as well as insts that reduce the different "critical paths" into one result. 
// The current fpu fence is quite strong (a branch) a weaker one might suffice.
// Currently not meant to be used ==> debug output done with errs().
//
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "RISCVInstrInfo.h"
#include "RISCVTargetMachine.h"
#include "RISCVMachineFunctionInfo.h"

#include "llvm/CodeGen/LivePhysRegs.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/LowLevelType.h"
#include "llvm/ADT/SmallSet.h"
#include "llvm/Support/CommandLine.h"

using namespace llvm;

#define DEBUG_TYPE "riscv-frep"

namespace llvm {
  cl::opt<bool> SnitchAutoFrep(
    "snitch-auto-frep", 
    cl::init(false), 
    cl::desc("Find repeating fp insts in unrolled loops. If a reduction can be found (not good yet) insert frep with stagger."));
}

#define SNITCH_AUTO_FREP_NAME "Snitch Auto Frep"

#define MAX_SEARCH_WINDOW 4
#define MIN_REP 4
#define MAX_STAGGER 4
#define NUM_SSR 3

namespace {

class SNITCHAutoFrep : public MachineFunctionPass {
public:
    const RISCVInstrInfo *TII;
    static char ID;

    SNITCHAutoFrep() : MachineFunctionPass(ID) {
      initializeSNITCHAutoFrepPass(*PassRegistry::getPassRegistry());
    }

    bool runOnMachineFunction(MachineFunction &MF) override;

    StringRef getPassName() const override { return SNITCH_AUTO_FREP_NAME; }

private:

    const MachineFunction *MF;
    RISCVMachineFunctionInfo *RVFI;
    DenseSet<unsigned> FPOps;

    bool process(MachineBasicBlock &MBB);
    bool isFPInstr(MachineInstr &I);
    std::pair<MachineBasicBlock::instr_iterator, unsigned> findRep(
        MachineBasicBlock::instr_iterator window_beg,
        MachineBasicBlock::instr_iterator window_end,
        MachineBasicBlock::instr_iterator end);
};

static Register getSSRFtReg(unsigned streamer) { //taken from RISCVExpandSSRInsts.cpp
  unsigned AssignedReg = RISCV::F0_D + streamer;
  // Advance the iterator to the assigned register until the valid
  // register is found
  const TargetRegisterClass *RC = &RISCV::FPR64RegClass;
  TargetRegisterClass::iterator I = RC->begin();
  for (; *I != AssignedReg; ++I)
    assert(I != RC->end() && "AssignedReg should be a member of provided RC");
  return Register(*I);
}

char SNITCHAutoFrep::ID = 0;

static constexpr unsigned fpopcodes[] = {RISCV::FADD_D, RISCV::FMUL_D, RISCV::FMADD_D, RISCV::FSGNJ_D, RISCV::FDIV_D, RISCV::FSUB_D, RISCV::FMSUB_D, RISCV::FMIN_D, RISCV::FMAX_D, RISCV::FSQRT_D};

bool SNITCHAutoFrep::runOnMachineFunction(MachineFunction &MF) {

    if (SnitchAutoFrep) {
        errs()<<"snitch auto frep on "<<MF.getName()<<"\n";
    } else {
        return true;
    }

    TII = static_cast<const RISCVInstrInfo *>(MF.getSubtarget().getInstrInfo());
    this->MF = &MF;
    this->RVFI = MF.getInfo<RISCVMachineFunctionInfo>();
    for (const unsigned &x : fpopcodes) this->FPOps.insert(x);

    errs()<<"autofrep: running on:"<<MF.getName()<<" ################################ \n";

    bool Modified = false;
    for (auto &MBB : MF) Modified |= process(MBB);

    errs()<<"autofrep: done with:"<<MF.getName()<<" ################################ \n";

    return Modified;
}

//very conservative
// return true if two insts do the same
static bool areTheSame(MachineInstr &A, MachineInstr &B){
    if (A.isBundled() || B.isBundled() || A.isDebugInstr() || B.isDebugInstr()) return false;
    bool same = A.getOpcode() == B.getOpcode();
    same &= A.getNumOperands() == B.getNumOperands();
    for (unsigned i = 0; same && i < A.getNumOperands(); i++) {
        MachineOperand &AOP = A.getOperand(i);
        MachineOperand &BOP = B.getOperand(i);
        same &= AOP.isIdenticalTo(BOP);
    }
    return same;
}

//FIXME: surely there is a better way to do this
bool SNITCHAutoFrep::isFPInstr(MachineInstr &I) {
    return this->FPOps.find(I.getOpcode()) != this->FPOps.end();
}

//test whether the window [window_beg, window_end) is repeating and how many times it is
std::pair<MachineBasicBlock::instr_iterator, unsigned> SNITCHAutoFrep::findRep(
    MachineBasicBlock::instr_iterator window_beg,
    MachineBasicBlock::instr_iterator window_end,
    MachineBasicBlock::instr_iterator end)
{
    MachineBasicBlock::instr_iterator wi = window_beg;
    MachineBasicBlock::instr_iterator s_end = window_end;
    MachineBasicBlock::instr_iterator s_res = window_end;
    unsigned rep = 1u;
    while (s_end != end && isFPInstr(*s_end) && areTheSame(*s_end, *wi)) {
        s_end++;
        wi++;
        if (wi == window_end) {
            wi = window_beg;
            rep++;
            s_res = s_end; //found rep
        }
    }
    return std::make_pair(s_res, rep);
}

//used to calculate best possible stagger amount
static unsigned getCycles(unsigned opcode) {
    switch (opcode)
    {
    case RISCV::FADD_D:
        return 2;
    case RISCV::FMUL_D:
        return 3;
    case RISCV::FMADD_D:
        return 4;
    default:
        return 1;
    }
}

//return reduction operation
//fmul.d not included because we currently always init the staggered regs with 0 (and mul would need 1)
//min/max might also work, anything associative should work
static Optional<unsigned> getCombineOpcode(unsigned opcode, unsigned src_idx) {
    switch (opcode)
    {
    case RISCV::FADD_D:
        if (src_idx == 1 || src_idx == 2) return (unsigned)RISCV::FADD_D;
        return None;
    case RISCV::FMADD_D:
        if (src_idx == 0) return (unsigned)RISCV::FADD_D;
        return None;
    default:
        return None;
    }
}

//combine usages to mask
static unsigned toMask (const std::vector<std::pair<MCRegister, unsigned>> &deps) {
    unsigned mask = 0u;
    for (const auto &p : deps) mask |= p.second;
    return mask;
}


//find internal and external dependencies
static Optional<std::vector<std::pair<MCRegister, unsigned>>> findRepDependenceRegs(
    MachineBasicBlock::instr_iterator window_begin, 
    MachineBasicBlock::instr_iterator window_end) 
{
    DenseMap<MCRegister, unsigned> def; //defs that are live going out of window
    std::vector<std::pair<MCRegister, unsigned>> internal, external;
    for (auto MII = window_begin; MII != window_end; MII++) {
        for (unsigned i = MII->getNumOperands()-1; i < MII->getNumOperands(); i--) {
            int idx = 3 - (int)i;
            auto &MOP = MII->getOperand(i);
            if (!MOP.isReg()) continue;
            if (idx < 0) return None; //there is an instruction with more than 4 fpr's in window ==> cannot stagger
            MCRegister r = MOP.getReg().asMCReg();
            if (MOP.isDef()) {
                if (idx != 3) return None; //defining operand not at idx 0 ==> cannot stagger
                def.insert(std::make_pair(r, (unsigned)(1 << idx)));
            } else { //use
                auto p = def.find(r);
                if (p != def.end()) internal.push_back(std::make_pair(r, (unsigned)(1 << idx) | p->second));
                if (MOP.isKill()) def.erase(r);
            }
            idx--;
        }
    }
    for (auto MII = window_begin; MII != window_end; MII++) {
        for (unsigned i = MII->getNumOperands()-1; i < MII->getNumOperands(); i--) {
            int idx = 3 - (int)i;
            auto &MOP = MII->getOperand(i);
            if (!MOP.isReg()) continue;
            assert(idx >= 0);
            MCRegister r = MOP.getReg().asMCReg();
            if (MOP.isDef()) {
                def.erase(r); //redef'ed before use
            } else {
                auto p = def.find(r);
                if (p != def.end()) external.push_back(std::make_pair(r, (unsigned)(1 << idx) | p->second));
                if (MOP.isKill()) def.erase(r);
            }
        }
    }
    unsigned internal_mask = toMask(internal);
    unsigned external_mask = toMask(external);
    for (auto &p : external) external_mask |= p.second;
    //internal needs to be a subset of external so that we can stagger (FIXME: right?)
    if ((internal_mask & external_mask) ^ internal_mask) return None;
    return external;
}

//merge dependecy vector
static void mergeRegisters(std::vector<std::pair<MCRegister, unsigned>> &deps) {
    unsigned i = 0;
    while (i < deps.size()) {
        MCRegister r = deps[i].first;
        unsigned found = 0u;
        for (unsigned j = 0; j < i; j++) {
            if (deps[j].first == r) {
                deps[j] = std::make_pair(r, deps[j].second | deps[i].first);
                found++;
            }
        }
        if (found) {
            assert(found == 1);
            deps.erase(deps.begin() + i);
            //no need to increment i
        } else {
            i++;
        }
    }
}

//duh
static bool isSSRReg(MCRegister r) {
    for (unsigned i = 0; i < NUM_SSR; i++) {
        if (getSSRFtReg(i) == r) return true;
    }
    return false;
}

//try to find readuction operation, currently only single ops are allowed
static Optional<std::vector<unsigned>> findCombineOps(
    MCRegister DReg, 
    unsigned stagger_mask, 
    MachineBasicBlock::instr_iterator window_begin,
    MachineBasicBlock::instr_iterator window_end) 
{
    MachineInstr *Def = nullptr;
    for (auto MII = std::next(window_end.getReverse()); MII != std::next(window_begin.getReverse()); MII++) {
        if (MII->getOperand(0).isReg() && MII->getOperand(0).getReg() == DReg) {
            Def = &*MII;
        }
    }
    if (!Def) return None;

    std::vector<unsigned> ops;
    MCRegister r = DReg;
    bool reached_def = false;
    for (auto MII = window_begin; !reached_def && MII != window_end; MII++) {
        for (unsigned i = MII->getNumOperands() - 1; !reached_def && i < MII->getNumOperands(); i--) {
            int idx = 3 - i;
            if (idx < 0) continue;
            auto &MOP = MII->getOperand(i);
            if (MOP.isReg() && MOP.getReg().asMCReg() == r) {
                if (!MII->getOperand(0).isReg()) return None;
                r = MII->getOperand(0).getReg().asMCReg();
                auto op = getCombineOpcode(MII->getOpcode(), (unsigned)idx);
                if (!op.hasValue()) return None;
                ops.push_back(op.getValue());
                reached_def = (&*MII == Def);
                if (!reached_def) return None; //FIXME: currently only one combineop allowed
                break; //go to next instruction
            }
        }
    }
    return ops;
}

struct StaggerInfo {
    unsigned count;
    unsigned mask;
    std::vector<MCRegister> regs;
    std::vector<unsigned> combineOps;
};

//try to find a way to stagger
static Optional<StaggerInfo> findStagger(
    MachineBasicBlock::instr_iterator window_begin,
    MachineBasicBlock::instr_iterator window_end,
    const LivePhysRegs &liveness,
    const llvm::MachineRegisterInfo &MRI)
{
    errs()<<"trying to find stagger\n";
    auto depsopt = findRepDependenceRegs(window_begin, window_end);
    if (!depsopt.hasValue()) return None;
    errs()<<"found deps\n";
    auto deps = depsopt.getValue();
    mergeRegisters(deps);
    for (const auto &p : deps) errs()<<"reg = "<<p.first<<", mask = "<<p.second<<"\n";
    bool contains_ssr_regs = false;
    for (const auto &p : deps) contains_ssr_regs |= isSSRReg(p.first);
    if (contains_ssr_regs) return None; //dependencies between ssr registers (FIXME: only do this if stream semantics are enabled)
    if (deps.size() != 1) return None; //more than one reg dependency is too complicated rn (FIXME)
    errs()<<"deps well-formed \n";
    MCRegister DReg = deps.front().first;
    unsigned stagger_mask = deps.front().second;
    auto ops = findCombineOps(DReg, stagger_mask, window_begin, window_end);
    if (!ops.hasValue()) return None;
    errs()<<"found combine ops\n";
    unsigned max_stagger_count = 0u;
    std::vector<MCRegister> regs;
    regs.push_back(DReg);
    while (max_stagger_count < MAX_STAGGER && liveness.available(MRI, DReg + max_stagger_count + 1)) {
        max_stagger_count++;
        regs.push_back(DReg + max_stagger_count);
    }
    if (!max_stagger_count) return None; //regs not free (FIXME: rename instead)
    StaggerInfo info;
    info.count = max_stagger_count;
    info.mask = stagger_mask;
    info.regs = std::move(regs);
    info.combineOps = std::move(ops.getValue());
    return info;
}

static MachineBasicBlock *findBB(MachineInstr &MI) {
    for (auto &MOP : MI.operands()) {
        if (MOP.isMBB()) return MOP.getMBB();
    }
    return nullptr;
}

//FIXME: no idea how to make a block a label for sure ==> just search for a branch and take its target
// there must be a better way to do this
// used for an always "dead" branch in the fpu fence
static MachineBasicBlock *findBrAbleBB(MachineBasicBlock &MBB) {
    if (!MBB.empty()) {
        auto *BB = findBB(*std::prev(MBB.end()));
        if (BB) return BB;
    }
    std::vector<MachineBasicBlock *> s;
    SmallSet<MachineBasicBlock *, 4> vis;
    s.push_back(&MBB);
    while (!s.empty()) {
        auto *B = s.back(); s.pop_back();
        if (!B || vis.contains(B)) continue;
        vis.insert(B);
        if (!B->empty()) {
            auto *x = findBB(*std::prev(B->end()));
            if (x) return x;
        }
        for (auto *BB : B->predecessors()) s.push_back(BB);
        for (auto *BB : B->successors()) s.push_back(BB);
    }
    return &MBB;
}

// work on a single BB, try to find repetitions, then try to find a way to stagger, then generate code if it gives an improvement
bool SNITCHAutoFrep::process(MachineBasicBlock &MBB) {
    bool Modified = false;

    recomputeLivenessFlags(MBB); //to be sure

    for (auto II = MBB.begin().getInstrIterator(); II != MBB.end().getInstrIterator(); ) {
        auto NII = std::next(II);
        if (II->isDebugInstr()) { //get rid of some dbg instructions (sorry)
            II->eraseFromParent();
        }
        II = NII;
    }

    MachineRegisterInfo &MRI = MBB.getParent()->getRegInfo();
    const TargetRegisterInfo &TRI = *MRI.getTargetRegisterInfo();
    LivePhysRegs liveness(TRI); //use RegScavenger ?
    liveness.addLiveIns(MBB);
    for (unsigned r = 0; r < NUM_SSR; r++) 
        liveness.addReg(getSSRFtReg(r).asMCReg()); //add SSR regs for good measure (FIXME: conservative)

    MachineBasicBlock::instr_iterator MII = MBB.begin().getInstrIterator();
    while (MII != MBB.end().getInstrIterator()){
        if (!isFPInstr(*MII)) {
            MII = std::next(MII);
            continue;
        }

        std::vector<std::pair<MachineBasicBlock::instr_iterator, unsigned>> search_results;
        for (auto II = MII; II != MBB.end().getInstrIterator() && search_results.size() < MAX_SEARCH_WINDOW; ++II) {
            auto wend = std::next(II);
            auto sr = findRep(MII, wend, MBB.end().getInstrIterator());
            search_results.push_back(sr);
        }

        unsigned best = 0u;
        for (unsigned i = 0u; i < search_results.size(); i++) {
            best = search_results[best].second < search_results[i].second ? i : best;
        }

        bool found = false;
        if (!search_results.empty() && search_results[best].second >= MIN_REP) { //if we have found at least MIN_REP repetitions
            errs()<<"found repeting fp instr's\n";
            for (auto II = MII; II != search_results[best].first; ++II) II->dump();
            const TargetRegisterClass *RC = &RISCV::GPRNoX0RegClass;
            TargetRegisterClass::iterator I = RC->begin();
            while(I != RC->end() && !liveness.available(MRI, MCPhysReg(*I))) I++;
            if (I != RC->end()) { //did find a free GPR register
                errs()<<"found a free GPR reg \n";

                MCPhysReg freeGPR = *I;
                
                const unsigned window_size = best + 1;  //recover window size
                const unsigned reps = search_results[best].second; //get reps

                auto delete_begin = std::next(MII, window_size); //start of repeting region
                auto delete_end = search_results[best].first;    //end of repeting region (excl.)

                auto info = findStagger(MII, delete_begin, liveness, MRI);

                if (info.hasValue()) {
                    errs()<<"found stagger \n";

                    unsigned window_cycles = 0u;
                    for (auto MI = MII; MI != delete_begin; MI++) window_cycles += getCycles(MI->getOpcode());
                    unsigned rep_stall = getCycles(std::prev(delete_begin)->getOpcode()) - 1u;
                    unsigned combine_cycles = 0u;
                    for (unsigned &op : info.getValue().combineOps) combine_cycles += getCycles(op);

                    std::vector<unsigned> cost;
                    cost.push_back(reps * window_cycles); //cycles needed with no frep
                    errs()<<"default = "<<cost[0]<<"\n";
                    for (unsigned stagger = 1u; stagger <= std::min(rep_stall, info.getValue().count); stagger++) {
                        unsigned stagger_log2 = 0u;
                        while ((1u << stagger_log2) < stagger+1) stagger_log2++;
                        errs()<<"num stagger regs = "<<(stagger + 1)<<", num combine ops = "<<stagger_log2<<"\n";
                        cost.push_back(
                            (reps * window_cycles) 
                            - ((stagger * reps) / (stagger + 1) * rep_stall) 
                            + 2u 
                            + stagger
                            + (stagger_log2 * combine_cycles));
                        errs()<<"frep + stagger("<<stagger<<") = "<<cost.back()<<"\n";
                    }

                    unsigned best_stagger = 0;
                    for (unsigned i = 0; i < cost.size(); i++) {
                        if (cost[i] < cost[best_stagger]) best_stagger = i;
                    }

                    if (best_stagger > 0u) {
                        errs()<<"frep+stagger is better\n";
                        //code generation:
                        //delete repetitions
                        MBB.dump();
                        found = true;
                        Modified = true; //we will modify now
                        
                        for (auto di = delete_begin; di != delete_end;) {
                            auto din = std::next(di);
                            di->eraseFromParentAndMarkDBGValuesForRemoval(); //delete repeated parts
                            di = din;
                        }
                        for (unsigned s = 1; s <= best_stagger; s++) {
                            //fcvt.d.w stagger, zero (FIXME: only allows additive combine op for now)
                            BuildMI(MBB, MII, MII->getDebugLoc(), this->TII->get(RISCV::FCVT_D_W), info.getValue().regs[s]) 
                                .addReg(RISCV::X0); 
                        }
                        //load rep
                        BuildMI(MBB, MII, MII->getDebugLoc(), this->TII->get(RISCV::ADDI), freeGPR)
                            .addReg(RISCV::X0)
                            .addImm(reps-1);
                        //frep.i 
                        BuildMI(MBB, MII, MII->getDebugLoc(), this->TII->get(RISCV::FREP_O))
                            .addReg(freeGPR, RegState::Kill)    //reps
                            .addImm(window_size)                //nr of instructions
                            .addImm(best_stagger)               //stagger count
                            .addImm(info.getValue().mask);      //stagger mask
                        
                        //combine result
                        errs()<<"generate combine result\n";
                        unsigned step = 1;
                        while (step < best_stagger + 1u) {
                            for (unsigned i = 0u; i + step < best_stagger + 1u; i += (step + 1)) {
                                //FIXME: currently only one combine op allowed, if more: need temp regs here ???
                                errs()<<"src = "<<i<<", dest = "<<(i+step)<<"\n";
                                BuildMI(MBB, delete_end, delete_end->getDebugLoc(), this->TII->get(info.getValue().combineOps.front()), info.getValue().regs[i])
                                    .addReg(info.getValue().regs[i], RegState::Kill)
                                    .addReg(info.getValue().regs[i + step], RegState::Kill)
                                    .addImm(7); 
                            }
                            step = step * 2;
                        }
                        
                        //FPU fence (as done in SNITCHFrepLoops.cpp)
                        BuildMI(MBB, delete_end, delete_end->getDebugLoc(), this->TII->get(RISCV::FMV_X_W), freeGPR)
                            .addReg(info.getValue().regs[1]);
                        auto *BB = findBrAbleBB(MBB);
                        BuildMI(MBB, delete_end, delete_end->getDebugLoc(), this->TII->get(RISCV::BLT))
                            .addReg(freeGPR, RegState::Kill)
                            .addReg(freeGPR, RegState::Kill)
                            .addMBB(BB);
                        //advance liveness
                        for (auto II = MII; II != delete_end; II++) {
                            SmallVector<std::pair<llvm::MCPhysReg, const llvm::MachineOperand *>, 4u> clobbers;
                            liveness.stepForward(*II, clobbers);
                        }
                        
                        MII = delete_end; //continue from here
                    }
                }
            }
        } 

        if (!found) {
            SmallVector<std::pair<llvm::MCPhysReg, const llvm::MachineOperand *>, 4u> clobbers;
            liveness.stepForward(*MII, clobbers);
            MII = std::next(MII);
        }
    }

    if (Modified) MBB.dump();

    return Modified;
}

} // end of anonymous namespace

INITIALIZE_PASS(SNITCHAutoFrep, "riscv-snitch-auto-frep",
                SNITCH_AUTO_FREP_NAME, false, false)
namespace llvm {

FunctionPass *createSNITCHAutoFrepPass() { return new SNITCHAutoFrep(); }

} // end of namespace llvm