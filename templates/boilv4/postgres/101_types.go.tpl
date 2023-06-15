{{- if .Table.IsView -}}
{{- else -}}
{{- $alias := .Aliases.Table .Table.Name -}}

// Expose table columns
var (
    {{$alias.UpSingular}}AllColumns = {{$alias.DownSingular}}AllColumns
    {{$alias.UpSingular}}ColumnsWithDefault = {{$alias.DownSingular}}ColumnsWithDefault
)

{{end -}}
