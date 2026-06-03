# TODO: Implementiert das Datenbank-Modul.
# Schaut euch variables.tf und outputs.tf an, bevor ihr anfangt.
#
data "aws_db_subnet_group" "db_subnet_group" {
  name = "${var.project}-${var.environment}-claims"
}

data "aws_security_group" "security_group" {
  name   = "${var.project}-${var.environment}-rds"
  vpc_id = var.vpc_id
}
resource "aws_db_instance" "db_instance" {
  identifier        = "${var.project}-${var.environment}-claims-jasper"
  engine            = "postgres"
  engine_version    = "16.6"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = data.aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [data.aws_security_group.security_group.id]

  publicly_accessible     = true
  skip_final_snapshot     = true
  backup_retention_period = 0
  deletion_protection     = false
}
