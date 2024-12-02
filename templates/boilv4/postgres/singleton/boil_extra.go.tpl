
import (
    "unsafe"

    "github.com/volatiletech/sqlboiler/v4/queries"
    "github.com/volatiletech/sqlboiler/v4/queries/qm"
)

const (
    MaxPageSize = 65000
)

var (
    DefaultPageSize = 1000
)

type queryMods []qm.QueryMod

func (m queryMods) Apply(q *queries.Query) {
    for _, mod := range m {
        mod.Apply(q)
    }
}

func chunkSlice[T any](slice []T, chunkSize int) [][]T {
    total := len(slice)
    if total == 0 {
        return [][]T{}
    }
    if total <= chunkSize {
        return [][]T{slice}
    }

    chunks := make([][]T, 0, total/chunkSize+1)
    for {
        if len(slice) == 0 {
            break
        }

        if len(slice) < chunkSize {
            chunkSize = len(slice)
        }

        chunks = append(chunks, slice[0:chunkSize])
        slice = slice[chunkSize:]
    }

    return chunks
}

func SplitInChunks[T any](slice []T) [][]T {
    return chunkSlice(slice, DefaultPageSize)
}

func SplitInChunksBySize[T any](slice []T, chunkSize int) [][]T {
    return chunkSlice(slice, chunkSize)
}

func unsafeGetString(b []byte) string {
    return *(*string)(unsafe.Pointer(&b))
}
