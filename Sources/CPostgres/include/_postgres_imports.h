// PostgreSQL Database Management System
// (also known as Postgres, formerly known as Postgres95)

// Portions Copyright (c) 1996-2025, PostgreSQL Global Development Group

// Portions Copyright (c) 1994, The Regents of the University of California

// Permission to use, copy, modify, and distribute this software and its
// documentation for any purpose, without fee, and without a written agreement
// is hereby granted, provided that the above copyright notice and this
// paragraph and the following two paragraphs appear in all copies.

// IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
// DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
// LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
// DOCUMENTATION, EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

// THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
// AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
// ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATIONS TO
// PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.

#include <pg_config.h>
#include <pg_config_manual.h>
#include <postgres_ext.h>
#include "_c.h"

extern char *pstrdup(const char *in);
extern void *palloc0(Size size);

#include "_postgres.h"
#include <datatype/timestamp.h>

typedef struct MemoryContextData *MemoryContext;
#include <fmgr.h>

// [elog.h]
#define Assert(condition)   ((void)true)
#define AssertMacro(condition)  ((void)true)
#define elog(elevel, ...) // note: this line disables logging
#define ERROR       21
// [/elog.h]

#include <access/tupdesc.h>
#include <access/htup.h>
#include <access/htup_details.h>
#include <varatt.h>

#include "_spi.h"

extern Oid  TypenameGetTypid(const char *typname);
extern Datum HeapTupleHeaderGetDatum(HeapTupleHeader tuple);
extern HeapTuple heap_form_tuple(TupleDesc tupleDescriptor,
                                 const Datum *values, const bool *isnull);

extern TupleDesc lookup_rowtype_tupdesc(Oid type_id, int32 typmod);

extern text *cstring_to_text(const char *s);
extern text *cstring_to_text_with_len(const char *s, int len);
