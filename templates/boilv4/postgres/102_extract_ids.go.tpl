{{- if .Table.IsView -}}
{{- else -}}
{{- $alias := .Aliases.Table .Table.Name -}}

{{range $column := .Table.Columns -}}
{{if eq $column.Name "id"}}
// GetIDs extract IDs from model objects
func (s {{$alias.UpSingular}}Slice) GetIDs() []{{$column.Type}} {
    result := make([]{{$column.Type}}, len(s))
    for i := range s {
        result[i] = s[i].ID
    }
    return result
}

// GetIntfIDs extract IDs from model objects as interface slice
func (s {{$alias.UpSingular}}Slice) GetIntfIDs() []interface{} {
    result := make([]interface{}, len(s))
    for i := range s {
        result[i] = s[i].ID
    }
    return result
}
{{end}}
{{end -}}

{{end -}}
