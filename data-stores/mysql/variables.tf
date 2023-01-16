variable "db_username" {
    description = "The username for the database"
    type        = string
    sensitive   = true # to indicate that the varable value is a secret so terraform won't log the value when running "plan or apply"
}

variable "db_password" {
    description = "The password for the database"
    type        = string
    sensitive   = true
}

variable "identifier" {
    description =  "identifier of the rds we want to create"
    type        = string
}

variable "engine_type" {
    description = "type of the rds engine"
    type        = string
}

variable "storage_size" {
    description = "storage size of rds"
    type        = number
}

variable "instance_type" {
    description = "instance type of RDS"
    type        = string
}

variable "name_rds" {
    description = "name of the rds"
    type        = string
}

variable "skip_final_snapshot" {
    description = "skip the taken of final snapshot before delete the rds"
    type        = bool
}

# variable "bucket_name" {
#     description = "name of s3 bucket where state file is saved"
#     type        = string
# }

# variable "bucket_key" {
#     description = "key of s3 bucket where state file is saved"
#     type        = string
# }