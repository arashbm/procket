CMD_DIR= $(dir$(lastword $(MAKEFILE_LIST)))../priv
CMD_PATH= $(CMD_DIR)/procket

ERTS_INCLUDE_DIR ?= $(shell erl -noshell -s init stop -eval "io:format(\"~s/erts-~s/include/\", [code:root_dir(), erlang:system_info(version)]).")
ERL_INTERFACE_INCLUDE_DIR ?= $(shell erl -noshell -s init stop -eval "io:format(\"~s\", [code:lib_dir(erl_interface, include)]).")
ERL_INTERFACE_LIB_DIR ?= $(shell erl -noshell -s init stop -eval "io:format(\"~s\", [code:lib_dir(erl_interface, lib)]).")

CFLAGS += -fPIC -I $(ERTS_INCLUDE_DIR) -I $(ERL_INTERFACE_INCLUDE_DIR)

all: dirs compile_cmd compile


dirs:
	-@mkdir -p $(CMD_DIR)

compile_cmd:
	$(CC) $(PROCKET_CFLAGS) -g -Wall -o $(CMD_PATH) -L. procket_cmd.c -lancillary

compile:
	$(CC) $(CFLAGS) -g -Wall -o $(CMD_PATH).so  procket.c -fpic -shared
