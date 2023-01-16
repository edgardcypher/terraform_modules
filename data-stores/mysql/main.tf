
# declare the cloud provider and the region in which the resource will be 
# deploy
provider "aws" {
    region = "us-east-2"
}

# define the rds resource we want to deploy
resource "aws_db_instance" "example" {
    identifier = var.identifier
    engine = var.engine_type
    allocated_storage = var.storage_size
    instance_class = var.instance_type
    skip_final_snapshot = var.skip_final_snapshot
    db_name             = var.name_rds
    final_snapshot_identifier = "${var.identifier}-snapshot"

    #how should we set the username and password?
    username = var.db_username
    password = var.db_password
}