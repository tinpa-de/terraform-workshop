# WORKSHOP-VEREINFACHUNG: DB Subnet Group wird vorab vom Admin angelegt.
# Participants haben keine rds:CreateDBSubnetGroup-Berechtigung – daher Lookup statt Anlegen.
data "aws_db_subnet_group" "claims" {
  name = "${var.project}-${var.environment}-claims"
}

# WORKSHOP-VEREINFACHUNG: Security Group wird vorab vom Admin angelegt.
# Participants haben keine ec2:CreateSecurityGroup-Berechtigung – daher Lookup statt Anlegen.
# In Produktion: Lambda in VPC + Security Group Referenzen statt CIDR.
data "aws_security_group" "rds" {
  name   = "${var.project}-${var.environment}-rds"
  vpc_id = var.vpc_id
}

resource "aws_db_instance" "claims" {
  identifier        = "${var.project}-${var.environment}-claims-jasper"
  engine            = "postgres"
  engine_version    = "16.6"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = data.aws_db_subnet_group.claims.name
  vpc_security_group_ids = [data.aws_security_group.rds.id]

  # WORKSHOP-VEREINFACHUNG: Lambda muss nicht in VPC laufen.
  # In Produktion: false + Lambda in VPC + private Subnets + NAT Gateway.
  publicly_accessible = true

  skip_final_snapshot     = true  # NUR FÜR WORKSHOP – in Produktion: false
  backup_retention_period = 0     # NUR FÜR WORKSHOP – in Produktion: >= 7
  deletion_protection     = false # NUR FÜR WORKSHOP

  tags = var.tags
}
