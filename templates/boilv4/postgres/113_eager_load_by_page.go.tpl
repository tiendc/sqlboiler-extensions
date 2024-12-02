{{- if or .Table.IsJoinTable .Table.IsView -}}
{{- else -}}
    {{- range $rel := .Table.ToManyRelationships -}}
        {{- $ltable := $.Aliases.Table $rel.Table -}}
        {{- $ftable := $.Aliases.Table $rel.ForeignTable -}}
        {{- $relAlias := $.Aliases.ManyRelationship $rel.ForeignTable $rel.Name $rel.JoinTable $rel.JoinLocalFKeyName -}}

// Load{{$relAlias.Local}}ByPage performs eager loading of values by page. This is for a 1-M or N-M relationship.
func (s {{$ltable.UpSingular}}Slice) Load{{$relAlias.Local}}ByPage(ctx context.Context, e boil.ContextExecutor, mods ...qm.QueryMod) error {
    return s.Load{{$relAlias.Local}}ByPageEx(ctx, e, DefaultPageSize, mods...)
}
func (s {{$ltable.UpSingular}}Slice) Load{{$relAlias.Local}}ByPageEx(ctx context.Context, e boil.ContextExecutor, pageSize int, mods ...qm.QueryMod) error {
    if len(s) == 0 {
        return nil
    }
    for _, chunk := range chunkSlice[*{{$ltable.UpSingular}}](s, pageSize) {
        if err := chunk[0].L.Load{{$relAlias.Local}}(ctx, e, false, &chunk, queryMods(mods)); err != nil {
            return err
        }
    }
    return nil
}

func (s {{$ltable.UpSingular}}Slice) GetLoaded{{$relAlias.Local}}() {{$ftable.UpSingular}}Slice {
    result := make({{$ftable.UpSingular}}Slice, 0, len(s)*2)
    for _, item := range s {
        if item.R == nil || item.R.{{$relAlias.Local}} == nil {
            continue
        }
        result = append(result, item.R.{{$relAlias.Local}}...)
    }
    return result
}

    {{end -}}{{/* range tomany */}}

    {{- range $rel := .Table.ToOneRelationships -}}
        {{- $ltable := $.Aliases.Table $rel.Table -}}
        {{- $ftable := $.Aliases.Table $rel.ForeignTable -}}
        {{- $relAlias := $ftable.Relationship $rel.Name -}}

// Load{{$relAlias.Local}}ByPage performs eager loading of values by page. This is for a 1-1 relationship.
func (s {{$ltable.UpSingular}}Slice) Load{{$relAlias.Local}}ByPage(ctx context.Context, e boil.ContextExecutor, mods ...qm.QueryMod) error {
    return s.Load{{$relAlias.Local}}ByPageEx(ctx, e, DefaultPageSize, mods...)
}
func (s {{$ltable.UpSingular}}Slice) Load{{$relAlias.Local}}ByPageEx(ctx context.Context, e boil.ContextExecutor, pageSize int, mods ...qm.QueryMod) error {
    if len(s) == 0 {
        return nil
    }
    for _, chunk := range chunkSlice[*{{$ltable.UpSingular}}](s, pageSize) {
        if err := chunk[0].L.Load{{$relAlias.Local}}(ctx, e, false, &chunk, queryMods(mods)); err != nil {
            return err
        }
    }
    return nil
}

func (s {{$ltable.UpSingular}}Slice) GetLoaded{{$relAlias.Local}}() {{$ftable.UpSingular}}Slice {
    result := make({{$ftable.UpSingular}}Slice, 0, len(s))
    for _, item := range s {
        if item.R == nil || item.R.{{$relAlias.Local}} == nil {
            continue
        }
        result = append(result, item.R.{{$relAlias.Local}})
    }
    return result
}
    {{end -}}{{/* range */}}

    {{- range $fkey := .Table.FKeys -}}
        {{- $ltable := $.Aliases.Table $fkey.Table -}}
        {{- $ftable := $.Aliases.Table $fkey.ForeignTable -}}
        {{- $rel := $ltable.Relationship $fkey.Name -}}
// Load{{plural $rel.Foreign}}ByPage performs eager loading of values by page. This is for a N-1 relationship.
func (s {{$ltable.UpSingular}}Slice) Load{{plural $rel.Foreign}}ByPage(ctx context.Context, e boil.ContextExecutor, mods ...qm.QueryMod) error {
    return s.Load{{plural $rel.Foreign}}ByPageEx(ctx, e, DefaultPageSize, mods...)
}
func (s {{$ltable.UpSingular}}Slice) Load{{plural $rel.Foreign}}ByPageEx(ctx context.Context, e boil.ContextExecutor, pageSize int, mods ...qm.QueryMod) error {
    if len(s) == 0 {
        return nil
    }
    for _, chunk := range chunkSlice[*{{$ltable.UpSingular}}](s, pageSize) {
        if err := chunk[0].L.Load{{$rel.Foreign}}(ctx, e, false, &chunk, queryMods(mods)); err != nil {
            return err
        }
    }
    return nil
}

func (s {{$ltable.UpSingular}}Slice) GetLoaded{{plural $rel.Foreign}}() {{$ftable.UpSingular}}Slice {
    result := make({{$ftable.UpSingular}}Slice, 0, len(s))
    mapCheckDup := make(map[*{{$ftable.UpSingular}}]struct{})
    for _, item := range s {
        if item.R == nil || item.R.{{$rel.Foreign}} == nil {
            continue
        }
        if _, ok := mapCheckDup[item.R.{{$rel.Foreign}}]; ok {
            continue
        }
        result = append(result, item.R.{{$rel.Foreign}})
        mapCheckDup[item.R.{{$rel.Foreign}}] = struct{}{}
    }
    return result
}
    {{end -}}{{/* range */}}


{{- end -}}{{/* if IsJoinTable */}}
