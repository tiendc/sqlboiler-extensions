{{- if .Table.IsView -}}
{{- else -}}
{{- $alias := .Aliases.Table .Table.Name -}}
{{- $mapKeyTypes := splitList "," "string,int,int8,int16,int32,int64,uint,uint8,uint16,uint32,uint64,byte,float32,float64,time.Time" -}}

{{range $column := .Table.Columns -}}
{{if and (eq $column.Name "id") (containsAny $mapKeyTypes $column.Type)}}
// ToIDMap convert a slice of model objects to a map with ID as key
func (s {{$alias.UpSingular}}Slice) ToIDMap() map[{{$column.Type}}]*{{$alias.UpSingular}} {
    result := make(map[{{$column.Type}}]*{{$alias.UpSingular}}, len(s))
    for _, o := range s {
        result[o.ID] = o
    }
    return result
}

// ToUniqueItems construct a slice of unique items from the given slice
func (s {{$alias.UpSingular}}Slice) ToUniqueItems() {{$alias.UpSingular}}Slice {
    result := make({{$alias.UpSingular}}Slice, 0, len(s))
    mapChk := make(map[{{$column.Type}}]struct{}, len(s))
    for i := len(s)-1; i>=0; i-- {
        o := s[i]
        if _, ok := mapChk[o.ID]; !ok {
            mapChk[o.ID] = struct{}{}
            result = append(result, o)
        }
    }
    return result
}

// FindItemByID find item by ID in the slice
func (s {{$alias.UpSingular}}Slice) FindItemByID(id {{$column.Type}}) *{{$alias.UpSingular}} {
    for _, o := range s {
        if o.ID == id {
            return o
        }
    }
    return nil
}

// FindMissingItemIDs find all item IDs that are not in the list
// NOTE: the input ID slice should contain unique values
func (s {{$alias.UpSingular}}Slice) FindMissingItemIDs(expectedIDs []{{$column.Type}}) []{{$column.Type}} {
    if len(s) == 0 {
        return expectedIDs
    }
    result := []{{$column.Type}}{}
    mapChk := s.ToIDMap()
    for _, id := range expectedIDs {
        if _, ok := mapChk[id]; !ok {
            result = append(result, id)
        }
    }
    return result
}
{{end}}

{{if and (eq $column.Name "id") (eq $column.Type "[]byte")}}
// ToIDMap convert a slice of model objects to a map with ID as key
// NOTE: use this function at your own risk as it transforms `[]byte` type to `string` to use it as map key
// Pass a custom converter function if you don't want to use trivial conversion from `[]byte` to `string`
func (s {{$alias.UpSingular}}Slice) ToIDMap(idConvFuncs ...func({{$column.Type}})string) map[string]*{{$alias.UpSingular}} {
    result := make(map[string]*{{$alias.UpSingular}}, len(s))
    var idConvFunc func({{$column.Type}})string
    if len(idConvFuncs) > 0 {
        idConvFunc = idConvFuncs[0]
    }

    for _, o := range s {
        if idConvFunc == nil {
            result[string(o.ID)] = o
        } else {
            result[idConvFunc(o.ID)] = o
        }
    }
    return result
}

// ToUniqueItems construct a slice of unique items from the given slice
func (s {{$alias.UpSingular}}Slice) ToUniqueItems() {{$alias.UpSingular}}Slice {
    result := make({{$alias.UpSingular}}Slice, 0, len(s))
    mapChk := make(map[string]struct{}, len(s))
    for i := len(s)-1; i>=0; i-- {
        o := s[i]
        if _, ok := mapChk[unsafeGetString(o.ID)]; !ok {
            mapChk[unsafeGetString(o.ID)] = struct{}{}
            result = append(result, o)
        }
    }
    return result
}

// FindItemByID find item by ID in the slice
func (s {{$alias.UpSingular}}Slice) FindItemByID(id {{$column.Type}}) *{{$alias.UpSingular}} {
    for _, o := range s {
        if reflect.DeepEqual(o.ID, id) {
            return o
        }
    }
    return nil
}

// FindMissingItemIDs find all item IDs that are not in the list
// NOTE: the input ID slice should contain unique values
func (s {{$alias.UpSingular}}Slice) FindMissingItemIDs(expectedIDs []{{$column.Type}}) []{{$column.Type}} {
    if len(s) == 0 {
        return expectedIDs
    }
    result := []{{$column.Type}}{}
    mapChk := s.ToIDMap()
    for _, id := range expectedIDs {
        if _, ok := mapChk[unsafeGetString(id)]; !ok {
            result = append(result, id)
        }
    }
    return result
}
{{end}}

{{end -}}

{{end -}}
