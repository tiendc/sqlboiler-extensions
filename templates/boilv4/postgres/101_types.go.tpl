{{- if .Table.IsView -}}
{{- else -}}
{{- $alias := .Aliases.Table .Table.Name -}}

// Expose table columns
var (
    {{$alias.UpSingular}}AllColumns = {{$alias.DownSingular}}AllColumns
    {{$alias.UpSingular}}ColumnsWithoutDefault = {{$alias.DownSingular}}ColumnsWithoutDefault
    {{$alias.UpSingular}}ColumnsWithDefault = {{$alias.DownSingular}}ColumnsWithDefault
    {{$alias.UpSingular}}PrimaryKeyColumns = {{$alias.DownSingular}}PrimaryKeyColumns
    {{$alias.UpSingular}}GeneratedColumns = {{$alias.DownSingular}}GeneratedColumns
)

{{end -}}
