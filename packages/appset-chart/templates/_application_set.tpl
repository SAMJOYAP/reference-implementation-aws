{{/*
Template to generate additional resources configuration
*/}}
{{- define "application-sets.additionalResources" -}}
{{- $chartName := .chartName -}}
{{- $chartConfig := .chartConfig -}}
{{- $valueFiles := .valueFiles -}}
{{- $values := .values -}}
{{- $repoURL := default $values.repoURLGit $chartConfig.repoURLGit -}}
{{- $repoRevision := default $values.repoURLGitRevision $chartConfig.repoURLGitRevision -}}
{{- $repoBasePath := default $values.repoURLGitBasePath $chartConfig.repoURLGitBasePath -}}
{{- $resourcePathName := default $chartName $chartConfig.additionalResourcesPathName -}}

{{- range $resource := $chartConfig.additionalResources }}
- repoURL: {{ $repoURL | squote }}
  targetRevision: {{ $repoRevision | squote }}
  path: {{- if eq $resource.type "manifests" }}
    '{{ $repoBasePath }}/{{ $resourcePathName }}{{ if $values.useValuesFilePrefix }}{{ $values.valuesFilePrefix }}{{ end }}/{{ $resource.manifestPath }}'
  {{- else }}
    {{ $resource.path | squote }}
  {{- end}}
  {{- if $resource.helm }}
  helm:
    releaseName: '{{`{{ .name }}`}}-{{ $resource.helm.releaseName }}'
    {{- if $resource.helm.valuesObject }}
    valuesObject:
    {{- $resource.helm.valuesObject | toYaml | nindent 6 }}
    {{- end }}
    ignoreMissingValueFiles: true
    valueFiles:
    {{- include "application-sets.valueFiles" (dict
      "nameNormalize" $chartName
      "chartConfig" $chartConfig
      "valueFiles" $valueFiles
      "values" $values
      "chartType" $resource.type) | nindent 6 }}
  {{- end }}
{{- end }}
{{- end }}


{{/*
Define the values path for reusability
*/}}
{{- define "application-sets.valueFiles" -}}
{{- $nameNormalize := .nameNormalize -}}
{{- $chartConfig := .chartConfig | default dict -}}
{{- $valueFiles := .valueFiles -}}
{{- $chartType := .chartType -}}
{{- $values := .values -}}
{{- $repoBasePath := default $values.repoURLGitBasePath $chartConfig.repoURLGitBasePath -}}
{{- $valuesPathName := default $nameNormalize $chartConfig.valuesPathName -}}
{{- with .valueFiles }}
{{- range . }}
- $values/{{ $repoBasePath }}/{{ $valuesPathName }}{{ if $chartType }}/{{ $chartType }}{{ end }}/{{ if $chartConfig.valuesFileName }}{{ $chartConfig.valuesFileName }}{{ else }}{{ . }}{{ end }}
{{- if $values.useValuesFilePrefix }}
- $values/{{ $repoBasePath }}/{{ if $values.useValuesFilePrefix }}{{ $values.valuesFilePrefix }}{{ end }}{{ . }}/{{ $valuesPathName }}{{ if $chartType }}/{{ $chartType }}{{ end }}/{{ if $chartConfig.valuesFileName }}{{ $chartConfig.valuesFileName }}{{ else }}values.yaml{{ end }}
{{- end }}
{{- end }}
{{- end }}
{{- with $chartConfig.valueFiles }}
{{- range . }}
- $values/{{ $repoBasePath }}/{{ $valuesPathName }}{{ if $chartType }}/{{ $chartType }}{{ end }}/{{ if $chartConfig.valuesFileName }}{{ $chartConfig.valuesFileName }}{{ else }}{{ . }}{{ end }}
{{- end }}
{{- end }}
{{- end }}
