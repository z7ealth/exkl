ERL_INCLUDE := $(shell erl -noshell -eval 'io:format("~s",[code:root_dir()]), halt().' )/usr/include

NIFS_DIR := priv/nifs

all: $(NIFS_DIR)/sensors_nif.so $(NIFS_DIR)/hid_api_nif.so

$(NIFS_DIR):
	mkdir -p $(NIFS_DIR)

$(NIFS_DIR)/sensors_nif.so: c_src/sensors_nif.c | $(NIFS_DIR)
	gcc -fPIC -shared \
		-I$(ERL_INCLUDE) \
		$< \
		-o $@ \
		-lsensors

$(NIFS_DIR)/hid_api_nif.so: c_src/hid_api_nif.c | $(NIFS_DIR)
	gcc -fPIC -shared \
		-I$(ERL_INCLUDE) \
		-I/usr/include/hidapi \
		$< \
		-o $@ \
		-lhidapi-hidraw

clean:
	rm -f $(NIFS_DIR)/*.so

.PHONY: all clean
