#include <erl_nif.h>

static ERL_NIF_TERM hello_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
   const char* res = "¡Hello, 🌍!";
    return enif_make_string(env, res, ERL_NIF_UTF8);
}

static ErlNifFunc nif_funcs[] = {
    {"hello", 0, hello_nif},
};

ERL_NIF_INIT(Elixir.Exkl.SensorsNif, nif_funcs, NULL, NULL, NULL, NULL)
