#include <erl_nif.h>
#include <hidapi.h>

// NIF Resource Type for hid_device handle
static ErlNifResourceType *HID_DEVICE_RESOURCE_TYPE = NULL;

static int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM info) {
  if (hid_init() != 0) {
    fprintf(stderr, "sensors_init failed\n");
    return -1;
  }
  return 0;
}

static void unload(ErlNifEnv *env, void *priv_data) { hid_exit(); }

// Destructor for the hid_device resource
static void hid_device_dtor(ErlNifEnv *env, void *obj) {
  hid_device *handle =
      *(hid_device **)obj; // Dereference the pointer to hid_device*
  if (handle) {
    hid_close(handle);
  }
}

static ERL_NIF_TERM open_nif(ErlNifEnv *env, int argc,
                             const ERL_NIF_TERM argv[]) {

  int vendor_id, product_id;
  hid_device *handle;
  ERL_NIF_TERM resource_term;

  if (!enif_get_int(env, argv[0], &vendor_id) ||
      !enif_get_int(env, argv[1], &product_id)) {
    return enif_make_badarg(env);
  }

  handle = hid_open(vendor_id, product_id, NULL);

  if (!handle) {
    printf("Unable to open device\n");
    hid_exit();
    return 1;
  }

  // Create a resource and attach the handle
  hid_device **res_handle = (hid_device **)enif_alloc_resource(
      HID_DEVICE_RESOURCE_TYPE, sizeof(hid_device *));
  if (!res_handle) {
    printf("Unable to create handle resource\n");
    hid_exit();
    return 1;
  }
  *res_handle = handle;
  resource_term = enif_make_resource(env, res_handle);
  enif_release_resource(
      res_handle); // Release our reference, Erlang VM now owns it

  return resource_term;
}

// --- NIF Exports ---
static ErlNifFunc nif_funcs[] = {
    {"open", 3, open_nif},
};

ERL_NIF_INIT(Elixir.Exkl.HidApiNif, nif_funcs, load, NULL, NULL, unload)
