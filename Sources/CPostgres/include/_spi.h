// [from spi.h]

#include <lib/ilist.h>

typedef struct SPITupleTable
{
    /* Public members */
    TupleDesc   tupdesc;        /* tuple descriptor */
    HeapTuple  *vals;           /* array of tuples */
    uint64      numvals;        /* number of valid tuples */

    /* Private members, not intended for external callers */
    uint64      alloced;        /* allocated length of vals array */
    MemoryContext tuptabcxt;    /* memory context of result table */
    slist_node  next;           /* link for internal bookkeeping */
    SubTransactionId subid;     /* subxact in which tuptable was created */
} SPITupleTable;

extern PGDLLIMPORT uint64 SPI_processed;
extern PGDLLIMPORT SPITupleTable *SPI_tuptable;
extern PGDLLIMPORT int SPI_result;

extern int  SPI_connect(void);
extern int  SPI_connect_ext(int options);
extern int  SPI_finish(void);
extern int  SPI_execute(const char *src, bool read_only, long tcount);
// extern int  SPI_register_trigger_data(TriggerData *tdata);

#define SPI_OK_CONNECT          1
#define SPI_OK_FINISH           2
#define SPI_OK_FETCH            3
#define SPI_OK_UTILITY          4
#define SPI_OK_SELECT           5
#define SPI_OK_SELINTO          6
#define SPI_OK_INSERT           7
#define SPI_OK_DELETE           8
#define SPI_OK_UPDATE           9
#define SPI_OK_CURSOR           10
#define SPI_OK_INSERT_RETURNING 11
#define SPI_OK_DELETE_RETURNING 12
#define SPI_OK_UPDATE_RETURNING 13
#define SPI_OK_REWRITTEN        14
#define SPI_OK_REL_REGISTER     15
#define SPI_OK_REL_UNREGISTER   16
#define SPI_OK_TD_REGISTER      17
#define SPI_OK_MERGE            18
#define SPI_OK_MERGE_RETURNING  19

// [spi.h]