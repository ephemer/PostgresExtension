#include "include/CPostgres.h"
#include <catalog/pg_enum.h>
#include <utils/syscache.h>

// importing `CPostgres` should be enough to get you this module marker:
PG_MODULE_MAGIC;

const char *get_enum_label(unsigned long long oid) {
    HeapTuple tup = SearchSysCache1(ENUMOID, ObjectIdGetDatum(oid));
    if (!HeapTupleIsValid(tup)) return NULL;

    Form_pg_enum en = (Form_pg_enum) GETSTRUCT(tup);
    char *label = pstrdup(NameStr(en->enumlabel));
    ReleaseSysCache(tup);

    return label;
}
