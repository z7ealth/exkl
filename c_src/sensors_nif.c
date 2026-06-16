#include <erl_nif.h>
#include <sensors/sensors.h>
#include <stdio.h>
#include <string.h>

typedef int (*chip_filter_fn)(const char *chip_name);

static int is_cpu_chip(const char *chip_name) {
  return strstr(chip_name, "k10temp") != NULL ||
         strstr(chip_name, "coretemp") != NULL ||
         strstr(chip_name, "zenpower") != NULL;
}

static int is_gpu_chip(const char *chip_name) {
  return strstr(chip_name, "amdgpu") != NULL ||
         strstr(chip_name, "nouveau") != NULL ||
         strstr(chip_name, "nvidia") != NULL ||
         strstr(chip_name, "radeon") != NULL ||
         strstr(chip_name, "i915") != NULL ||
         strstr(chip_name, "xe") != NULL;
}

static double get_temp_for_chips(chip_filter_fn filter) {
  int chip_nr = 0;
  double temp = 0.0;
  const sensors_chip_name *chip;

  while ((chip = sensors_get_detected_chips(NULL, &chip_nr)) != NULL) {
    char chip_name_buf[256];
    sensors_snprintf_chip_name(chip_name_buf, sizeof(chip_name_buf), chip);

    if (!filter(chip_name_buf)) {
      continue;
    }

    int feature_nr = 0;
    const sensors_feature *feature;

    while ((feature = sensors_get_features(chip, &feature_nr)) != NULL) {
      if (feature->type == SENSORS_FEATURE_TEMP) {
        int subfeature_nr = 0;
        const sensors_subfeature *subfeature;

        while ((subfeature = sensors_get_all_subfeatures(
                    chip, feature, &subfeature_nr)) != NULL) {
          if (subfeature->type == SENSORS_SUBFEATURE_TEMP_INPUT) {
            if (sensors_get_value(chip, subfeature->number, &temp) == 0) {
              return temp;
            }
          }
        }
      }
    }
  }

  return -1.0;
}

static double get_power_for_chips(chip_filter_fn filter) {
  int chip_nr = 0;
  double power = 0.0;
  const sensors_chip_name *chip;

  while ((chip = sensors_get_detected_chips(NULL, &chip_nr)) != NULL) {
    char chip_name_buf[256];
    sensors_snprintf_chip_name(chip_name_buf, sizeof(chip_name_buf), chip);

    if (!filter(chip_name_buf)) {
      continue;
    }

    int feature_nr = 0;
    const sensors_feature *feature;

    while ((feature = sensors_get_features(chip, &feature_nr)) != NULL) {
      if (feature->type == SENSORS_FEATURE_POWER) {
        int subfeature_nr = 0;
        const sensors_subfeature *subfeature;

        while ((subfeature = sensors_get_all_subfeatures(
                    chip, feature, &subfeature_nr)) != NULL) {
          if (subfeature->type == SENSORS_SUBFEATURE_POWER_INPUT ||
              subfeature->type == SENSORS_SUBFEATURE_POWER_AVERAGE) {
            if (sensors_get_value(chip, subfeature->number, &power) == 0 &&
                power > 0.0) {
              return power;
            }
          }
        }
      }
    }
  }

  return -1.0;
}

double get_cpu_temp_celsius() { return get_temp_for_chips(is_cpu_chip); }

double get_gpu_temp_celsius() { return get_temp_for_chips(is_gpu_chip); }

double get_gpu_power_watts() { return get_power_for_chips(is_gpu_chip); }

double get_cpu_temp_fahrenheit() {
  return (get_cpu_temp_celsius() * 9.0 / 5.0) + 32.0;
}

static ERL_NIF_TERM get_cpu_temp_celsius_nif(ErlNifEnv *env, int argc,
                                             const ERL_NIF_TERM argv[]) {
  (void)argc;
  (void)argv;
  return enif_make_double(env, get_cpu_temp_celsius());
}

static ERL_NIF_TERM get_cpu_temp_fahrenheit_nif(ErlNifEnv *env, int argc,
                                                const ERL_NIF_TERM argv[]) {
  (void)argc;
  (void)argv;
  return enif_make_double(env, get_cpu_temp_fahrenheit());
}

static ERL_NIF_TERM get_gpu_temp_celsius_nif(ErlNifEnv *env, int argc,
                                             const ERL_NIF_TERM argv[]) {
  (void)argc;
  (void)argv;
  return enif_make_double(env, get_gpu_temp_celsius());
}

static ERL_NIF_TERM get_gpu_power_watts_nif(ErlNifEnv *env, int argc,
                                            const ERL_NIF_TERM argv[]) {
  (void)argc;
  (void)argv;
  return enif_make_double(env, get_gpu_power_watts());
}

static int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM info) {
  (void)env;
  (void)priv_data;
  (void)info;
  if (sensors_init(NULL) != 0) {
    fprintf(stderr, "sensors_init failed\n");
    return -1;
  }
  return 0;
}

static void unload(ErlNifEnv *env, void *priv_data) {
  (void)env;
  (void)priv_data;
  sensors_cleanup();
}

static ErlNifFunc nif_funcs[] = {
    {"get_cpu_temp_celsius", 0, get_cpu_temp_celsius_nif, 0},
    {"get_cpu_temp_fahrenheit", 0, get_cpu_temp_fahrenheit_nif, 0},
    {"get_gpu_temp_celsius", 0, get_gpu_temp_celsius_nif, 0},
    {"get_gpu_power_watts", 0, get_gpu_power_watts_nif, 0}};

ERL_NIF_INIT(Elixir.Exkl.SensorsNif, nif_funcs, load, NULL, NULL, unload)
