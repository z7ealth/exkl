#include <erl_nif.h>
#include <hidapi.h>

#define MAX_STR 255
#define MAX_UTF8_STR_LEN (MAX_STR * 4)

// NIF Resource Type for hid_device handle
static ErlNifResourceType *HID_DEVICE_RESOURCE_TYPE = NULL;

// Destructor for the hid_device resource
static void hid_device_dtor(ErlNifEnv *env, void *obj) {
  hid_device *handle =
      *(hid_device **)obj; // Dereference the pointer to hid_device*
  if (handle) {
    hid_close(handle);
  }
}

static int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM info) {
  if (hid_init() != 0) {
    fprintf(stderr, "sensors_init failed\n");
    return 1;
  }

  HID_DEVICE_RESOURCE_TYPE = enif_open_resource_type(
      env, "Elixir.Exkl.HidApiNif", "HIDDevice", &hid_device_dtor,
      ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER, NULL);

  if (HID_DEVICE_RESOURCE_TYPE == NULL)
    return -1;

  return 0;
}

static void unload(ErlNifEnv *env, void *priv_data) { hid_exit(); }

static ERL_NIF_TERM open_nif(ErlNifEnv *env, int argc,
                             const ERL_NIF_TERM argv[]) {

  int vendor_id, product_id;
  hid_device *handle;
  ERL_NIF_TERM resource_term;

  if (argc != 2 || !enif_get_int(env, argv[0], &vendor_id) ||
      !enif_get_int(env, argv[1], &product_id)) {
    return enif_make_badarg(env);
  }

  handle = hid_open(vendor_id, product_id, NULL);

  if (!handle) {
    printf("Unable to open device\n");
    hid_exit();
    return enif_make_int(env, 1);
  }

  // Create a resource and attach the handle
  hid_device **res_handle = (hid_device **)enif_alloc_resource(
      HID_DEVICE_RESOURCE_TYPE, sizeof(hid_device *));

  if (!res_handle) {
    printf("Unable to create handle resource\n");
    hid_exit();
    return enif_make_int(env, 1);
  }
  *res_handle = handle;
  resource_term = enif_make_resource(env, res_handle);
  enif_release_resource(
      res_handle); // Release our reference, Erlang VM now owns it

  return resource_term;
}

static ERL_NIF_TERM close_nif(ErlNifEnv *env, int argc,
                              const ERL_NIF_TERM argv[]) {
  hid_device **res_handle;
  if (argc != 1 ||
      !enif_get_resource(env, argv[0], HID_DEVICE_RESOURCE_TYPE,
                         (void **)&res_handle) ||
      *res_handle == NULL) {
    return enif_make_badarg(env);
  }
  // Set the pointer in the resource to NULL.
  // This marks it as "closed" from the NIF's perspective and prevents
  // double-free if `close` is called multiple times. The actual hid_close will
  // happen when the resource is finally garbage collected.
  *res_handle = NULL;
  return enif_make_int(env, 0);
}

static ERL_NIF_TERM write_nif(ErlNifEnv *env, int argc,
                              const ERL_NIF_TERM argv[]) {
  hid_device **res_handle;
  ErlNifBinary data_bin;
  int res;

  if (argc != 2 ||
      !enif_get_resource(env, argv[0], HID_DEVICE_RESOURCE_TYPE,
                         (void **)&res_handle) ||
      *res_handle == NULL || !enif_inspect_binary(env, argv[1], &data_bin)) {
    return enif_make_badarg(env);
  }

  res = hid_write(*res_handle, data_bin.data, data_bin.size);

  if (res < 0) {
    const wchar_t *error_wstr = hid_error(*res_handle);
    char error_msg_buf[MAX_UTF8_STR_LEN];
    size_t error_len = 0;
    if (error_wstr) {
      error_len = wcstombs(error_msg_buf, error_wstr, MAX_UTF8_STR_LEN - 1);
      if (error_len == (size_t)-1) {
        snprintf(
            error_msg_buf, MAX_UTF8_STR_LEN,
            "hid_write failed (conversion error for hidapi error message)");
        error_len = strlen(error_msg_buf);
      }
    } else {
      snprintf(error_msg_buf, MAX_UTF8_STR_LEN,
               "hid_write failed (no specific hidapi error message)");
      error_len = strlen(error_msg_buf);
    }
    error_msg_buf[error_len] = '\0';
    return enif_make_int(env, 1);
  }
  return enif_make_int(env, 0);
}

// --- NIF Exports ---
static ErlNifFunc nif_funcs[] = {
    {"open", 2, open_nif}, {"close", 1, close_nif}, {"write", 2, write_nif}};

ERL_NIF_INIT(Elixir.Exkl.HidApiNif, nif_funcs, load, NULL, NULL, unload)
