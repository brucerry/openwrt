ifeq ($(PLAT),)
$(error "target platform cannot be empty")
endif

EXEC		:= mtk-efuse-tool
SRCS		:= mtk_efuse.c efuse_nl.c efuse_utils.c

ifneq ($(wildcard platform/$(PLAT)/plat_efuse.c),)
SRCS		+= platform/$(PLAT)/plat_efuse.c
else
OBJS		:= platform/$(PLAT)/plat_efuse.o
endif

OBJS		+= $(patsubst %.c,%.o,$(SRCS))
PLAT_CFLAGS	+= -DPLAT=\"$(PLAT)\"

%.o: %.c
	@echo "  CC      $<"
	$(CC) $(CFLAGS) $(PLAT_CFLAGS) -c $< -o $@

$(EXEC): $(OBJS)
	@echo " LD       $@"
	$(CC) $(LDFLAGS) -o $@ $(OBJS)

.PHONY: all clean
all: $(EXEC)

clean:
	rm -f $(EXEC) *.o
