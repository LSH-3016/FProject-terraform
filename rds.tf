# RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-postgres"

  # Engine
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro"
  
  # Storage
  allocated_storage     = 20
  max_allocated_storage = 100  # 스토리지 자동 조정 활성화
  storage_type          = "gp3"
  storage_encrypted     = true  # 암호화 활성화

  # Database
  db_name  = "onedb"
  username = var.db_username
  password = var.db_password
  port     = 5432

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = true  # Multi-AZ 활성화

  # Backup
  backup_retention_period = 7  # 자동 백업 활성화 (7일 보관)
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Upgrades
  auto_minor_version_upgrade = true  # 마이너 버전 자동 업그레이드

  # Other
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name        = "${var.project_name}-postgres"
    Environment = "dev"
  }
}
