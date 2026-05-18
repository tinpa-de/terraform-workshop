resource "aws_db_subnet_group" "claims" {
  name       = "${var.project}-${var.environment}-claims"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.environment}-rds"
  description = "Allow PostgreSQL access from Lambda functions"
  vpc_id      = var.vpc_id

  # Ingress wird über separate Rule angelegt, um Zirkularität zwischen
  # processor- und database-Modul zu vermeiden (Lambda-SG referenziert RDS-SG nicht direkt).
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_security_group_rule" "rds_ingress_from_lambda" {
  count                    = length(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = var.allowed_security_group_ids[count.index]
  description              = "PostgreSQL from Lambda SG"
}

resource "aws_db_instance" "claims" {
  identifier              = "${var.project}-${var.environment}-claims"
  engine                  = "postgres"
  engine_version          = "16.3"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  storage_encrypted       = true
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.claims.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  skip_final_snapshot     = true  # NUR FÜR WORKSHOP - in Produktion: false
  publicly_accessible     = false
  backup_retention_period = 0     # NUR FÜR WORKSHOP - in Produktion: >= 7
  deletion_protection     = false # NUR FÜR WORKSHOP

  tags = var.tags
}
