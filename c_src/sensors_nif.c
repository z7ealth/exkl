#include <erl_nif.h>
#include <sensors/sensors.h>
#include <string.h>

double get_cpu_temp_celcius() {
  int chip_nr = 0;
  double temp = 0.0;
  const sensors_chip_name *chip;

  while ((chip = sensors_get_detected_chips(NULL, &chip_nr)) != NULL) {
    char chip_name_buf[256];
    sensors_snprintf_chip_name(chip_name_buf, sizeof(chip_name_buf), chip);

    if (strstr(chip_name_buf, "k10temp") || strstr(chip_name_buf, "coretemp")) {
      printf("Detected CPU sensor: %s\n", chip_name_buf);

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
  return (get_cpu_temp_celcius() * 9.0 / 5.0) + 32.0;
}

static ERL_NIF_TERM get_cpu_temp_celcius_nif(ErlNifEnv *env, int argc,
                                             const ERL_NIF_TERM argv[]) {
  return enif_make_double(env, get_cpu_temp_celcius());
}

static ERL_NIF_TERM get_cpu_temp_fahrenheit_nif(ErlNifEnv *env, int argc,
                                             const ERL_NIF_TERM argv[]) {
  double temp = get_cpu_temp_celcius();

  return enif_make_double(env, get_cpu_temp_fahrenheit());
}

static ERL_NIF_TERM hello_nif(ErlNifEnv *env, int argc,
                              const ERL_NIF_TERM argv[]) {
  const char *str = "¡Hello, 🌍!"; // Your UTF-8 string
  size_t len = strlen(str);        // Get length in bytes

  ErlNifBinary bin;
  if (!enif_alloc_binary(len, &bin)) {
    return enif_make_atom(env, "error_allocating_binary");
  }

  get_cpu_temp_celcius();

  memcpy(bin.data, str, len);

  return enif_make_binary(env, &bin);
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
    {"hello", 0, hello_nif},
    {"get_cpu_temp_celcius", 0, get_cpu_temp_celcius_nif},
    {"get_cpu_temp_fahrenheit", 0, get_cpu_temp_fahrenheit_nif}
};

ERL_NIF_INIT(Elixir.Exkl.SensorsNif, nif_funcs, load, NULL, NULL, unload)
