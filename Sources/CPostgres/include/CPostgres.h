#pragma once

#include "_postgres_imports.h"

typedef struct {
    const unsigned char *data;
    size_t count;
} text_view;

static inline text_view pg_text_view(Datum d)
{
    struct varlena *v = PG_DETOAST_DATUM_PACKED(d);

    text_view out;
    out.data = (const unsigned char *) VARDATA_ANY(v);
    out.count  = (size_t) VARSIZE_ANY_EXHDR(v);
    return out;
}

static inline __attribute__((always_inline))
const NullableDatum *get_args(FunctionCallInfo fcinfo) {
    return fcinfo->args;
};

static inline __attribute__((always_inline))
const DatumTupleFields get_datum_tuple_fields(HeapTupleHeader header) {
    return header->t_choice.t_datum;
};

static inline __attribute__((always_inline))
unsigned int varsize_length(struct varlena* input) {
    return VARSIZE_ANY_EXHDR(input);
}

const char *get_enum_label(unsigned long long oid);
