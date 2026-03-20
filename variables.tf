variable "location" {
  type        = string
  description = "Azure region to deploy resources."
}

variable "cpu" {
  type        = string
  default     = "0.5"
  description = <<EOF
The amount of CPUs to request and limit the job.
You can also specify milliCPU with a "m" suffix. For example, "0.5" equals "500m".
By default, this is set to 0.5 CPU.
EOF
}

variable "memory" {
  type        = string
  default     = "512Mi"
  description = <<EOF
The amount of memory to reserve and cap the job.
If the job exceeds this amount, it will be killed with exit code 127 representing "Out-of-memory".
Memory is measured in Mi, or megabytes.
EOF
}

variable "command" {
  type        = list(string)
  default     = []
  description = <<EOF
This overrides the `CMD` specified in the image.
Specify a blank list to use the image's `CMD`.
Each token in the command is an item in the list.
For example, `echo "Hello World"` would be represented as ["echo", "\"Hello World\""].
EOF
}

variable "image_url" {
  type    = string
  default = ""

  description = <<EOF
This allows you to override the image used for the application.
If blank, Nullstone will create an image repository and provide management of images.
If you configure image_url, you can still use `nullstone deploy --version=<...>` to deploy a specific image tag.
EOF
}
