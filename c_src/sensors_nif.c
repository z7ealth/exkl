#include <erl_nif.h>
#include <sensors/sensors.h>
#include <string.h>

double get_cpu_temp_celsius() {
  int chip_nr = 0;
  double temp = 0.0;
  const sensors_chip_name *chip;

  while ((chip = sensors_get_detected_chips(NULL, &chip_nr)) != NULL) {
    char chip_name_buf[256];
    sensors_snprintf_chip_name(chip_name_buf, sizeof(chip_name_buf), chip);

    if (strstr(chip_name_buf, "k10temp") || strstr(chip_name_buf, "coretemp")) {
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
                return temp; // Return the first valid temperature found
              }
            }
          }
        }
      }
    }
  }

  return -1.0;
}

double get_cpu_temp_fahrenheit() {
  return (get_cpu_temp_celsius() * 9.0 / 5.0) + 32.0;
}

static ERL_NIF_TERM get_cpu_temp_celsius_nif(ErlNifEnv *env, int argc,
                                             const ERL_NIF_TERM argv[]) {
  return enif_make_double(env, get_cpu_temp_celsius());
}

static ERL_NIF_TERM get_cpu_temp_fahrenheit_nif(ErlNifEnv *env, int argc,
                                             const ERL_NIF_TERM argv[]) {
  double temp = get_cpu_temp_celsius();

  return enif_make_double(env, get_cpu_temp_fahrenheit());
}

// --- NIF Lifecycle ---

static int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM info) {
  if (sensors_init(NULL) != 0) {
    fprintf(stderr, "sensors_init failed\n");
    return -1;
  }
  return 0;
}

static void unload(ErlNifEnv *env, void *priv_data) { sensors_cleanup(); }

// --- NIF Exports ---
static ErlNifFunc nif_funcs[] = {
    {"get_cpu_temp_celsius", 0, get_cpu_temp_celsius_nif},
    {"get_cpu_temp_fahrenheit", 0, get_cpu_temp_fahrenheit_nif}
};

ERL_NIF_INIT(Elixir.Exkl.SensorsNif, nif_funcs, load, NULL, NULL, unload)
