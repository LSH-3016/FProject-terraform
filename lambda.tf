# Lambda Layer for pg (Node.js PostgreSQL client)
resource "null_resource" "lambda_layer" {
  provisioner "local-exec" {
    command     = "if not exist lambda_layer\\nodejs mkdir lambda_layer\\nodejs && cd lambda_layer\\nodejs && npm init -y && npm install pg"
    working_dir = path.module
  }

  triggers = {
    run_once = "4"
  }
}

data "archive_file" "lambda_layer" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_layer"
  output_path = "${path.module}/lambda_layer.zip"

  depends_on = [null_resource.lambda_layer]
}

resource "aws_lambda_layer_version" "pg" {
  filename            = data.archive_file.lambda_layer.output_path
  layer_name          = "${var.project_name}-pg-layer"
  compatible_runtimes = ["nodejs18.x", "nodejs20.x"]
  source_code_hash    = data.archive_file.lambda_layer.output_base64sha256

  depends_on = [data.archive_file.lambda_layer]
}

# Lambda function code
data "archive_file" "db_init" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/db_init"
  output_path = "${path.module}/db_init.zip"
}

# Lambda IAM Role
resource "aws_iam_role" "lambda_db_init" {
  name = "${var.project_name}-lambda-db-init-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_db_init.name
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda_db_init.name
}

# Security Group for Lambda
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg"
  description = "Security group for Lambda function"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-lambda-sg"
  }
}

# Allow Lambda to access RDS
resource "aws_security_group_rule" "rds_from_lambda" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = aws_security_group.rds.id
}

# Lambda Function
resource "aws_lambda_function" "db_init" {
  filename         = data.archive_file.db_init.output_path
  function_name    = "${var.project_name}-db-table-create"
  role             = aws_iam_role.lambda_db_init.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.db_init.output_base64sha256
  runtime          = "nodejs20.x"
  timeout          = 60
  memory_size      = 256

  layers = [aws_lambda_layer_version.pg.arn]

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_HOST     = aws_db_instance.main.address
      DB_NAME     = aws_db_instance.main.db_name
      DB_USER     = var.db_username
      DB_PASSWORD = var.db_password
      DB_PORT     = tostring(aws_db_instance.main.port)
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_db_instance.main
  ]

  tags = {
    Name = "${var.project_name}-db-table-create"
  }
}

# Invoke Lambda after RDS is ready
resource "aws_lambda_invocation" "db_init" {
  function_name = aws_lambda_function.db_init.function_name

  input = jsonencode({
    action = "init"
  })

  triggers = {
    run_once = "3"
  }

  lifecycle {
    ignore_changes = [input]
  }

  depends_on = [
    aws_lambda_function.db_init,
    aws_db_instance.main,
    aws_nat_gateway.main
  ]
}
