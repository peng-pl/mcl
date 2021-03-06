include common.mk
LIB_DIR=lib
OBJ_DIR=obj
EXE_DIR=bin
SRC_SRC=fp.cpp bn_c256.cpp bn_c384.cpp bn_c512.cpp she_c256.cpp
TEST_SRC=fp_test.cpp ec_test.cpp fp_util_test.cpp window_method_test.cpp elgamal_test.cpp fp_tower_test.cpp gmp_test.cpp bn_test.cpp bn384_test.cpp glv_test.cpp paillier_test.cpp she_test.cpp vint_test.cpp bn512_test.cpp ecdsa_test.cpp conversion_test.cpp
TEST_SRC+=bn_c256_test.cpp bn_c384_test.cpp bn_c512_test.cpp she_c256_test.cpp she_c384_test.cpp
TEST_SRC+=aggregate_sig_test.cpp array_test.cpp
TEST_SRC+=bls12_test.cpp
TEST_SRC+=ecdsa_c_test.cpp
ifeq ($(CPU),x86-64)
  MCL_USE_XBYAK?=1
  TEST_SRC+=mont_fp_test.cpp sq_test.cpp
  ifeq ($(USE_LOW_ASM),1)
    TEST_SRC+=low_test.cpp
  endif
  ifeq ($(MCL_USE_XBYAK),1)
    TEST_SRC+=fp_generator_test.cpp
  endif
endif
SAMPLE_SRC=bench.cpp ecdh.cpp random.cpp rawbench.cpp vote.cpp pairing.cpp large.cpp tri-dh.cpp bls_sig.cpp pairing_c.c she_smpl.cpp

ifneq ($(MCL_MAX_BIT_SIZE),)
  CFLAGS+=-DMCL_MAX_BIT_SIZE=$(MCL_MAX_BIT_SIZE)
endif
ifeq ($(MCL_USE_XBYAK),0)
  CFLAGS+=-DMCL_DONT_USE_XBYAK
endif
SHARE_BASENAME_SUF?=_dy
##################################################################
MCL_LIB=$(LIB_DIR)/libmcl.a
MCL_SNAME=mcl$(SHARE_BASENAME_SUF)
BN256_SNAME=mclbn256$(SHARE_BASENAME_SUF)
BN384_SNAME=mclbn384$(SHARE_BASENAME_SUF)
BN512_SNAME=mclbn512$(SHARE_BASENAME_SUF)
SHE256_SNAME=mclshe256$(SHARE_BASENAME_SUF)
MCL_SLIB=$(LIB_DIR)/lib$(MCL_SNAME).$(LIB_SUF)
BN256_LIB=$(LIB_DIR)/libmclbn256.a
BN256_SLIB=$(LIB_DIR)/lib$(BN256_SNAME).$(LIB_SUF)
BN384_LIB=$(LIB_DIR)/libmclbn384.a
BN384_SLIB=$(LIB_DIR)/lib$(BN384_SNAME).$(LIB_SUF)
BN512_LIB=$(LIB_DIR)/libmclbn512.a
BN512_SLIB=$(LIB_DIR)/lib$(BN512_SNAME).$(LIB_SUF)
SHE256_LIB=$(LIB_DIR)/libmclshe256.a
SHE384_LIB=$(LIB_DIR)/libmclshe384.a
ECDSA_LIB=$(LIB_DIR)/libmclecdsa.a
all: $(MCL_LIB) $(MCL_SLIB) $(BN256_LIB) $(BN256_SLIB) $(SHE256_LIB) $(ECDSA_LIB)
#$(BN384_LIB) $(BN384_SLIB) $(BN512_LIB) $(BN512_SLIB) $(SHE384_lib)

#LLVM_VER=-3.8
LLVM_LLC=llc$(LLVM_VER)
LLVM_OPT=opt$(LLVM_VER)
LLVM_OPT_VERSION=$(shell $(LLVM_OPT) --version 2>/dev/null | awk '/version/ {print $$3}')
GEN_EXE=src/gen
# incompatibility between llvm 3.4 and the later version
ifneq ($(LLVM_OPT_VERSION),)
ifeq ($(shell expr $(LLVM_OPT_VERSION) \< 3.5.0),1)
  GEN_EXE_OPT=-old
endif
endif
ifeq ($(OS),mac)
  ASM_SRC_PATH_NAME=src/asm/$(CPU)mac
else
  ASM_SRC_PATH_NAME=src/asm/$(CPU)
endif
ifneq ($(CPU),)
  ASM_SRC=$(ASM_SRC_PATH_NAME).s
endif
ASM_OBJ=$(OBJ_DIR)/$(CPU).o
LIB_OBJ=$(OBJ_DIR)/fp.o
BN256_OBJ=$(OBJ_DIR)/bn_c256.o
BN384_OBJ=$(OBJ_DIR)/bn_c384.o
BN512_OBJ=$(OBJ_DIR)/bn_c512.o
SHE256_OBJ=$(OBJ_DIR)/she_c256.o
SHE384_OBJ=$(OBJ_DIR)/she_c384.o
ECDSA_OBJ=$(OBJ_DIR)/ecdsa_c.o
FUNC_LIST=src/func.list
MCL_USE_LLVM?=1
ifeq ($(MCL_USE_LLVM),1)
  CFLAGS+=-DMCL_USE_LLVM=1
  LIB_OBJ+=$(ASM_OBJ)
endif
LLVM_SRC=src/base$(BIT).ll

# CPU is used for llvm
# see $(LLVM_LLC) --version
LLVM_FLAGS=-march=$(CPU) -relocation-model=pic #-misched=ilpmax
LLVM_FLAGS+=-pre-RA-sched=list-ilp -max-sched-reorder=128 -mattr=-sse

#HAS_BMI2=$(shell cat "/proc/cpuinfo" | grep bmi2 >/dev/null && echo "1")
#ifeq ($(HAS_BMI2),1)
#  LLVM_FLAGS+=-mattr=bmi2
#endif

ifeq ($(USE_LOW_ASM),1)
  LOW_ASM_OBJ=$(LOW_ASM_SRC:.asm=.o)
  LIB_OBJ+=$(LOW_ASM_OBJ)
endif
# special case for intel with bmi2
ifeq ($(INTEL),1)
  LIB_OBJ+=$(OBJ_DIR)/$(CPU).bmi2.o
endif

ifeq ($(UPDATE_ASM),1)
  ASM_SRC_DEP=$(LLVM_SRC)
  ASM_BMI2_SRC_DEP=src/base$(BIT).bmi2.ll
else
  ASM_SRC_DEP=
  ASM_BMI2_SRC_DEP=
endif

$(MCL_LIB): $(LIB_OBJ)
	$(AR) $@ $(LIB_OBJ)

$(MCL_SLIB): $(LIB_OBJ)
	$(PRE)$(CXX) -o $@ $(LIB_OBJ) -shared $(LDFLAGS)

$(BN256_LIB): $(BN256_OBJ)
	$(AR) $@ $(BN256_OBJ)

$(SHE256_LIB): $(SHE256_OBJ)
	$(AR) $@ $(SHE256_OBJ)

$(SHE384_LIB): $(SHE384_OBJ)
	$(AR) $@ $(SHE384_OBJ)

$(ECDSA_LIB): $(ECDSA_OBJ)
	$(AR) $@ $(ECDSA_OBJ)

ifeq ($(OS),mac)
  MAC_LDFLAGS+=-l$(MCL_SNAME) -L./lib
endif
$(BN256_SLIB): $(BN256_OBJ) $(MCL_SLIB)
	$(PRE)$(CXX) -o $@ $(BN256_OBJ) -shared $(LDFLAGS) $(MAC_LDFLAGS)

$(BN384_LIB): $(BN384_OBJ)
	$(AR) $@ $(BN384_OBJ)

$(BN512_LIB): $(BN512_OBJ)
	$(AR) $@ $(BN512_OBJ)

$(BN384_SLIB): $(BN384_OBJ) $(MCL_SLIB)
	$(PRE)$(CXX) -o $@ $(BN384_OBJ) -shared $(LDFLAGS) $(MAC_LDFLAGS)

$(BN512_SLIB): $(BN512_OBJ) $(MCL_SLIB)
	$(PRE)$(CXX) -o $@ $(BN512_OBJ) -shared $(LDFLAGS) $(MAC_LDFLAGS)

$(ASM_OBJ): $(ASM_SRC)
	$(PRE)$(CXX) -c $< -o $@ $(CFLAGS)

$(ASM_SRC): $(ASM_SRC_DEP)
	$(LLVM_OPT) -O3 -o - $< -march=$(CPU) | $(LLVM_LLC) -O3 -o $@ $(LLVM_FLAGS)

$(LLVM_SRC): $(GEN_EXE) $(FUNC_LIST)
	$(GEN_EXE) $(GEN_EXE_OPT) -f $(FUNC_LIST) > $@

$(ASM_SRC_PATH_NAME).bmi2.s: $(ASM_BMI2_SRC_DEP)
	$(LLVM_OPT) -O3 -o - $< -march=$(CPU) | $(LLVM_LLC) -O3 -o $@ $(LLVM_FLAGS) -mattr=bmi2

$(OBJ_DIR)/$(CPU).bmi2.o: $(ASM_SRC_PATH_NAME).bmi2.s
	$(PRE)$(CXX) -c $< -o $@ $(CFLAGS)

src/base$(BIT).bmi2.ll: $(GEN_EXE)
	$(GEN_EXE) $(GEN_EXE_OPT) -f $(FUNC_LIST) -s bmi2 > $@

src/base64m.ll: $(GEN_EXE)
	$(GEN_EXE) $(GEN_EXE_OPT) -wasm > $@

$(FUNC_LIST): $(LOW_ASM_SRC)
ifeq ($(USE_LOW_ASM),1)
	$(shell awk '/global/ { print $$2}' $(LOW_ASM_SRC) > $(FUNC_LIST))
	$(shell awk '/proc/ { print $$2}' $(LOW_ASM_SRC) >> $(FUNC_LIST))
else
	$(shell touch $(FUNC_LIST))
endif

$(GEN_EXE): src/gen.cpp src/llvm_gen.hpp
	$(CXX) -o $@ $< $(CFLAGS) -O0

asm: $(LLVM_SRC)
	$(LLVM_OPT) -O3 -o - $(LLVM_SRC) | $(LLVM_LLC) -O3 $(LLVM_FLAGS) -x86-asm-syntax=intel

$(LOW_ASM_OBJ): $(LOW_ASM_SRC)
	$(ASM) $<

ifeq ($(OS),mac)
  MAC_GO_LDFLAGS="-ldflags=-s"
endif
test_go256: $(MCL_SLIB) $(BN256_SLIB)
	cd ffi/go/mcl && env LD_RUN_PATH="../../../lib" CGO_CFLAGS="-I../../../include" CGO_LDFLAGS="-L../../../lib -l$(BN256_SNAME) -l$(MCL_SNAME) -lgmpxx -lgmp -lcrypto -lstdc++" go test $(MAC_GO_LDFLAGS) -tags bn256 .

test_go384: $(MCL_SLIB) $(BN384_SLIB)
	cd ffi/go/mcl && env LD_RUN_PATH="../../../lib" CGO_CFLAGS="-I../../../include" CGO_LDFLAGS="-L../../../lib -l$(BN384_SNAME) -l$(MCL_SNAME) -lgmpxx -lgmp -lcrypto -lstdc++" go test $(MAC_GO_LDFLAGS) .

test_go:
	$(MAKE) test_go256
	$(MAKE) test_go384

test_java:
	$(MAKE) -C ffi/java test

##################################################################

VPATH=test sample src

.SUFFIXES: .cpp .d .exe .c .o

$(OBJ_DIR)/%.o: %.cpp
	$(PRE)$(CXX) $(CFLAGS) -c $< -o $@ -MMD -MP -MF $(@:.o=.d)

$(OBJ_DIR)/%.o: %.c
	$(PRE)$(CC) $(CFLAGS) -c $< -o $@ -MMD -MP -MF $(@:.o=.d)

$(EXE_DIR)/%.exe: $(OBJ_DIR)/%.o $(MCL_LIB)
	$(PRE)$(CXX) $< -o $@ $(MCL_LIB) $(LDFLAGS)

$(EXE_DIR)/bn_c256_test.exe: $(OBJ_DIR)/bn_c256_test.o $(BN256_LIB) $(MCL_LIB)
	$(PRE)$(CXX) $< -o $@ $(BN256_LIB) $(MCL_LIB) $(LDFLAGS)

$(EXE_DIR)/bn_c384_test.exe: $(OBJ_DIR)/bn_c384_test.o $(BN384_LIB) $(MCL_LIB)
	$(PRE)$(CXX) $< -o $@ $(BN384_LIB) $(MCL_LIB) $(LDFLAGS)

$(EXE_DIR)/bn_c512_test.exe: $(OBJ_DIR)/bn_c512_test.o $(BN512_LIB) $(MCL_LIB)
	$(PRE)$(CXX) $< -o $@ $(BN512_LIB) $(MCL_LIB) $(LDFLAGS)

$(EXE_DIR)/pairing_c.exe: $(OBJ_DIR)/pairing_c.o $(BN256_LIB) $(MCL_LIB)
	$(PRE)$(CC) $< -o $@ $(BN256_LIB) $(MCL_LIB) $(LDFLAGS) -lstdc++

$(EXE_DIR)/she_c256_test.exe: $(OBJ_DIR)/she_c256_test.o $(SHE256_LIB) $(MCL_LIB)
	$(PRE)$(CXX) $< -o $@ $(SHE256_LIB) $(MCL_LIB) $(LDFLAGS)

$(EXE_DIR)/she_c384_test.exe: $(OBJ_DIR)/she_c384_test.o $(SHE384_LIB) $(MCL_LIB)
	$(PRE)$(CXX) $< -o $@ $(SHE384_LIB) $(MCL_LIB) $(LDFLAGS)

$(EXE_DIR)/ecdsa_c_test.exe: $(OBJ_DIR)/ecdsa_c_test.o $(ECDSA_LIB) $(MCL_LIB) src/ecdsa_c.cpp include/mcl/ecdsa.hpp include/mcl/ecdsa.h
	$(PRE)$(CXX) $< -o $@ $(ECDSA_LIB) $(MCL_LIB) $(LDFLAGS)

SAMPLE_EXE=$(addprefix $(EXE_DIR)/,$(addsuffix .exe,$(basename $(SAMPLE_SRC))))
sample: $(SAMPLE_EXE) $(MCL_LIB)

TEST_EXE=$(addprefix $(EXE_DIR)/,$(TEST_SRC:.cpp=.exe))
test: $(TEST_EXE)
	@echo test $(TEST_EXE)
	@sh -ec 'for i in $(TEST_EXE); do $$i|grep "ctest:name"; done' > result.txt
	@grep -v "ng=0, exception=0" result.txt; if [ $$? -eq 1 ]; then echo "all unit tests succeed"; else exit 1; fi

EMCC_OPT=-I./include -I./src -I../cybozulib/include -Wall -Wextra
EMCC_OPT+=-O3 -DNDEBUG -DMCLSHE_WIN_SIZE=8
EMCC_OPT+=-s WASM=1 -s NO_EXIT_RUNTIME=1 -s MODULARIZE=1 #-s ASSERTIONS=1
EMCC_OPT+=-DCYBOZU_MINIMUM_EXCEPTION
EMCC_OPT+=-s ABORTING_MALLOC=0
SHE_C_DEP=src/fp.cpp src/she_c_impl.hpp include/mcl/she.hpp include/mcl/she.h Makefile
MCL_C_DEP=src/fp.cpp src/bn_c_impl.hpp include/mcl/bn.hpp include/mcl/bn.h Makefile
ifeq ($(MCL_USE_LLVM),2)
  EMCC_OPT+=src/base64m.ll -DMCL_USE_LLVM
  SHE_C_DEP+=src/base64m.ll
endif
../she-wasm/she_c.js: src/she_c256.cpp $(SHE_C_DEP)
	emcc -o $@ src/fp.cpp src/she_c256.cpp $(EMCC_OPT) -DMCL_MAX_BIT_SIZE=256 -s TOTAL_MEMORY=67108864 -s DISABLE_EXCEPTION_CATCHING=0

../she-wasm/she_c384.js: src/she_c384.cpp $(SHE_C_DEP)
	emcc -o $@ src/fp.cpp src/she_c384.cpp $(EMCC_OPT) -DMCL_MAX_BIT_SIZE=384 -s TOTAL_MEMORY=67108864 -s DISABLE_EXCEPTION_CATCHING=0

../mcl-wasm/mcl_c.js: src/bn_c256.cpp $(MCL_C_DEP)
	emcc -o $@ src/fp.cpp src/bn_c256.cpp $(EMCC_OPT) -DMCL_MAX_BIT_SIZE=256 -DMCL_USE_WEB_CRYPTO_API -s DISABLE_EXCEPTION_CATCHING=1 -DCYBOZU_DONT_USE_EXCEPTION -DCYBOZU_DONT_USE_STRING -fno-exceptions -MD -MP -MF obj/mcl_c.d

../mcl-wasm/mcl_c512.js: src/bn_c512.cpp $(MCL_C_DEP)
	emcc -o $@ src/fp.cpp src/bn_c512.cpp $(EMCC_OPT) -DMCL_MAX_BIT_SIZE=512 -DMCL_USE_WEB_CRYPTO_API -s DISABLE_EXCEPTION_CATCHING=1 -DCYBOZU_DONT_USE_EXCEPTION -DCYBOZU_DONT_USE_STRING -fno-exceptions

../ecdsa-wasm/ecdsa_c.js: src/ecdsa_c.cpp src/fp.cpp include/mcl/ecdsa.hpp include/mcl/ecdsa.h Makefile
	emcc -o $@ src/fp.cpp src/ecdsa_c.cpp $(EMCC_OPT) -DMCL_MAX_BIT_SIZE=256 -DMCL_USE_WEB_CRYPTO_API -s DISABLE_EXCEPTION_CATCHING=1 -DCYBOZU_DONT_USE_EXCEPTION -DCYBOZU_DONT_USE_STRING -fno-exceptions

mcl-wasm:
	$(MAKE) ../mcl-wasm/mcl_c.js
	$(MAKE) ../mcl-wasm/mcl_c512.js

she-wasm:
	$(MAKE) ../she-wasm/she_c.js
	$(MAKE) ../she-wasm/she_c384.js

ecdsa-wasm:
	$(MAKE) ../ecdsa-wasm/ecdsa_c.js

# test
bin/emu:
	$(CXX) -g -o $@ src/fp.cpp src/bn_c256.cpp test/bn_c256_test.cpp -DMCL_DONT_USE_XBYAK -DMCL_DONT_USE_OPENSSL -DMCL_USE_VINT -DMCL_SIZEOF_UNIT=8 -DMCL_VINT_64BIT_PORTABLE -DMCL_VINT_FIXED_BUFFER -DMCL_MAX_BIT_SIZE=256 -I./include -I../cybozulib/include
bin/pairing_c_min.exe:
	$(CXX) -o $@ sample/pairing_c.c src/fp.cpp src/bn_c256.cpp -Ofast -g -I./include -I../cybozulib/include -fno-exceptions -fno-rtti -fno-threadsafe-statics -DMCL_DONT_USE_XBYAK -DMCL_DONT_USE_OPENSSL -DMCL_USE_VINT -DMCL_SIZEOF_UNIT=8 -DMCL_VINT_FIXED_BUFFER -DCYBOZU_DONT_USE_EXCEPTION -DCYBOZU_DONT_USE_STRING -DMCL_DONT_USE_CSPRNG -DMCL_MAX_BIT_SIZE=256

clean:
	$(RM) $(MCL_LIB) $(MCL_SLIB) $(BN256_LIB) $(BN256_SLIB) $(BN384_LIB) $(BN384_SLIB) $(BN512_LIB) $(BN512_SLIB) $(SHE256_LIB) $(OBJ_DIR)/*.o $(OBJ_DIR)/*.d $(EXE_DIR)/*.exe $(GEN_EXE) $(ASM_OBJ) $(LIB_OBJ) $(BN256_OBJ) $(BN384_OBJ) $(BN512_OBJ) $(LLVM_SRC) $(FUNC_LIST) src/*.ll

ALL_SRC=$(SRC_SRC) $(TEST_SRC) $(SAMPLE_SRC)
DEPEND_FILE=$(addprefix $(OBJ_DIR)/, $(addsuffix .d,$(basename $(ALL_SRC))))
-include $(DEPEND_FILE)

PREFIX?=/usr/local
install: lib/libmcl.a lib/libmcl$(SHARE_BASENAME_SUF).$(LIB_SUF)
	$(MAKE) -C ../cybozulib install PREFIX=$(PREFIX)
	$(MKDIR) $(PREFIX)/include/mcl
	cp -a include/mcl/ $(PREFIX)/include/
	$(MKDIR) $(PREFIX)/lib
	cp -a lib/libmcl.a lib/libmcl$(SHARE_BASENAME_SUF).$(LIB_SUF) $(PREFIX)/lib/

.PHONY: test mcl-wasm she-wasm bin/emu

# don't remove these files automatically
.SECONDARY: $(addprefix $(OBJ_DIR)/, $(ALL_SRC:.cpp=.o))

