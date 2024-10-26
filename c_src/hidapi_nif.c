#include <erl_nif.h>
#include <hidapi/hidapi_libusb.h>

static ERL_NIF_TERM hid_init_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    return enif_make_int(env, hid_init());
}

static ERL_NIF_TERM hid_exit_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    return enif_make_int(env, hid_exit());
}

static ERL_NIF_TERM hid_open_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    hid_device *handle;
    unsigned short vendor_id, product_id;

    if (!enif_get_uint(env, argv[0], &vendor_id))
    {
        return enif_make_badarg(env);
    }

    if (!enif_get_uint(env, argv[1], &product_id))
    {
        return enif_make_badarg(env);
    }

    handle = hid_open(vendor_id, product_id, NULL);
    return enif_make_int(env, hid_exit());
}

static ErlNifFunc nif_funcs[] = {
    {"hid_init", 0, hid_init_nif},
    {"hid_exit", 0, hid_exit_nif},
};

ERL_NIF_INIT(Elixir.Exkl.Hidapi.HidapiNif, nif_funcs, NULL, NULL, NULL, NULL)