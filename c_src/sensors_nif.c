#include <erl_nif.h>
#include <sensors/sensors.h>
#include <string.h>

typedef int (*chip_filter_fn)(const char *chip_name);

static int is_cpu_chip(const char *chip_name) {
  return strstr(chip_name, "k10temp") != NULL ||
         strstr(chip_name, "coretemp") != NULL;
}

static int is_gpu_chip(const char *chip_name) {
  return strstr(chip_name, "amdgpu") != NULL ||
         strstr(chip_name, "nouveau") != NULL ||
         strstr(chip_name, "nvidia") != NULL ||
         strstr(chip_name, "radeon") != NULL;
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

double get_cpu_temp_celsius() { return get_temp_for_chips(is_cpu_chip); }

double get_gpu_temp_celsius() { return get_temp_for_chips(is_gpu_chip); }

double get_cpu_temp_fahrenheit() {
  return (get_cpu_temp_celsius() * 9.0 / 5.0) + 32.0;
}

static ERL_NIF_TERM get_cpu_temp_celsius_nif(ErlNifEnv *env, int argc,
                                             const ERL_NIF_TERM argv[]) {
  return enif_make_double(env, get_cpu_temp_celsius());
}

static ERL_NIF_TERM get_cpu_temp_fahrenheit_nif(ErlNifEnv *env, int argc,
                                                const ERL_NIF_TERM argv[]) {
  return enif_make_double(env, get_cpu_temp_fahrenheit());
}

static ERL_NIF_TERM get_gpu_temp_celsius_nif(ErlNifEnv *env, int argc,
                                             const ERL_NIF_TERM argv[]) {
  return enif_make_double(env, get_gpu_temp_celsius());
}

static int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM info) {
  if (sensors_init(NULL) != 0) {
    fprintf(stderr, "sensors_init failed\n");
    return -1;
  }
  return 0;
}

static void unload(ErlNifEnv *env, void *priv_data) { sensors_cleanup(); }

static ErlNifFunc nif_funcs[] = {
    {"get_cpu_temp_celsius", 0, get_cpu_temp_celsius_nif},
    {"get_cpu_temp_fahrenheit", 0, get_cpu_temp_fahrenheit_nif},
    {"get_gpu_temp_celsius", 0, get_gpu_temp_celsius_nif}};

ERL_NIF_INIT(Elixir.Exkl.SensorsNif, nif_funcs, load, NULL, NULL, unload)
