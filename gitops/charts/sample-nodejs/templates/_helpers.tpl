{{/*
Name of every object: the release name, with the chart name added unless the
release name already contains it. Kubernetes names stop at 63 characters.
*/}}
{{- define "sample-nodejs.fullname" -}}
{{- if contains .Chart.Name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Labels that select the app's pods. They must never change for a release,
because a Deployment's selector is immutable.
*/}}
{{- define "sample-nodejs.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Standard labels for every object and for the pods. The version is the image
tag, because the image is what carries the app version.
*/}}
{{- define "sample-nodejs.labels" -}}
{{ include "sample-nodejs.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | trunc 63 | trimSuffix "-" | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
The image reference. Both parts come from the Environment's values file.
*/}}
{{- define "sample-nodejs.image" -}}
{{- $repository := required "image.repository must be set in the Environment's values file" .Values.image.repository }}
{{- $tag := required "image.tag must be set in the Environment's values file" .Values.image.tag }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
