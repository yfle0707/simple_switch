ifndef SDE_INSTALL
$(error SDE_INSTALL is not set)
endif

P4_PROG = ampel_switch
ARCH = tofino
SOURCES = main.c

CC = gcc

CFLAGS  = -DSDE_INSTALL=\"$(SDE_INSTALL)\"              \
          -I$(SDE_INSTALL)/include                      \
          -I$(SDE_INSTALL)/include/$(ARCH)/pdfixed       \
          -I$(SDE_INSTALL)/include/$(ARCH)pd/$(P4_PROG)

BF_LIBS  = -lbf_switchd_lib        \
           -ltofinopdfixed_thrift  \
           -lavago                 \
           -ldriver                \
           -lbfutils               \
           -lbfsys

LDFLAGS  = -Wl,-rpath,$(SDE_INSTALL)/lib
LDFLAGS += -Wl,-rpath,$(SDE_INSTALL)/lib/$(ARCH)pd/$(P4_PROG)
LDLIBS   = -L$(SDE_INSTALL)/lib -L$(SDE_INSTALL)/lib/$(ARCH)pd/$(P4_PROG)
LDLIBS  += -Wl,--start-group $(BF_LIBS) -Wl,--end-group
LDLIBS  += -lm -pthread -lstdc++ -ldl -levent -lthrift -lz


all: $(P4_PROG)_cp


$(P4_PROG)_cp: main.c
	$(CC) $(CFLAGS) $(SOURCES) -o $(P4_PROG)_cp $(LDLIBS) $(LDFLAGS)

clean:
	rm $(P4_PROG)_cp *.log zlog-cfg-cur
