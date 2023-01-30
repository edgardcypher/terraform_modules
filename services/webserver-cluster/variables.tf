variable "server_port" {
    description = "the port that will be used by the web server for http requests"
    type = number
    default = 8080
}

variable "elb_port" {
    description = "the port that will be used by the elb server to listen http requests"
    type = number
    default = 80
}

variable "cluster_name" {
    description = "The name use for all the cluster resources"
    type        = string 
}

variable "db_remote_state_bucket" {
    description = "The name of the s3 bucket for the DB remote state"
    default     = "edgard-terraform-state"
    type        = string
}

variable "db_remote_state_key" {
    description = "The path for the DB remote state in S3"
    default     = "state/data-stores/mysql/terraform.tfstate"
    type        = string
}

variable "instance_type" {
  description = "The type of EC2 Instances to run (e.g. t2.micro)"
  type        = string
}

variable "min_size" {
  description = "The minimum number of EC2 Instances in the ASG"
  type        = number
}

variable "max_size" {
  description = "The maximum number of EC2 Instances in the ASG"
  type        = number
}

variable "custom_tags" {
  description = "mapping of customs tags"
  type  = map(string)
  default = {}
}