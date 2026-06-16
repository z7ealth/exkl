# Native NIFs for EXKL (built automatically via `mix compile` / elixir_make).
#
# Runtime dependencies (development headers + libraries):
#   - Erlang/OTP development headers (erlang package)
#   - GCC
#   - lm_sensors (libsensors) — CPU temperature / fan sensors
#   - hidapi (hidraw) — DeepCool HID display communication
#
# Desktop UI additionally needs wxWidgets GTK3 + WebKitGTK at runtime
# (not required to compile these NIFs).

ERL_INCLUDE := $(shell erl -noshell -eval 'io:format("~s",[code:root_dir()]), halt().' )/usr/include

NIFS_DIR := priv/nifs

HIDAPI_CFLAGS ?= $(shell pkg-config --cflags hidapi-hidraw 2>/dev/null)
HIDAPI_LIBS ?= $(shell pkg-config --libs hidapi-hidraw 2>/dev/null)

ifeq ($(strip $(HIDAPI_CFLAGS)),)
HIDAPI_CFLAGS := -I/usr/include/hidapi
endif

ifeq ($(strip $(HIDAPI_LIBS)),)
HIDAPI_LIBS := -lhidapi-hidraw
endif

SENSORS_CFLAGS ?= $(shell pkg-config --cflags libsensors 2>/dev/null)
SENSORS_LIBS ?= $(shell pkg-config --libs libsensors 2>/dev/null)

ifeq ($(strip $(SENSORS_LIBS)),)
SENSORS_LIBS := -lsensors
endif

CFLAGS := -fPIC -shared -Wall -Wextra -O2 -std=c11 \
	-Werror=implicit-function-declaration -Werror=missing-field-initializers

.PHONY: all clean deps-check

all: $(NIFS_DIR)/sensors_nif.so $(NIFS_DIR)/hid_api_nif.so

deps-check:
	@echo "Checking build dependencies..."
	@command -v gcc >/dev/null || (echo "Missing: gcc" && exit 1)
	@command -v erl >/dev/null || (echo "Missing: erlang" && exit 1)
	@test -f "$(ERL_INCLUDE)/erl_nif.h" || (echo "Missing: erlang development headers ($(ERL_INCLUDE)/erl_nif.h)" && exit 1)
	@pkg-config --exists libsensors 2>/dev/null || test -f /usr/include/sensors/sensors.h || (echo "Missing: lm_sensors / libsensors headers" && exit 1)
	@pkg-config --exists hidapi-hidraw 2>/dev/null || test -f /usr/include/hidapi/hidapi.h || test -f /usr/include/hidapi.h || (echo "Missing: hidapi headers" && exit 1)
	@echo "Build dependencies look OK."

$(NIFS_DIR):
	mkdir -p $(NIFS_DIR)

$(NIFS_DIR)/sensors_nif.so: c_src/sensors_nif.c | $(NIFS_DIR)
	gcc $(CFLAGS) $(SENSORS_CFLAGS) \
		-I$(ERL_INCLUDE) \
		$< \
		-o $@ \
		$(SENSORS_LIBS)

$(NIFS_DIR)/hid_api_nif.so: c_src/hid_api_nif.c | $(NIFS_DIR)
	gcc $(CFLAGS) $(HIDAPI_CFLAGS) \
		-I$(ERL_INCLUDE) \
		$< \
		-o $@ \
		$(HIDAPI_LIBS)

clean:
	rm -f $(NIFS_DIR)/*.so
