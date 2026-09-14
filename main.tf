resource "aws_vpc" "vpc-nwl-346" {
  tags       = merge(var.tags, { Name = "vpc-nwl-346" })
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "snet-public-nwl-346" {
  vpc_id                  = aws_vpc.vpc-nwl-346.id
  tags                    = merge(var.tags, { Name = "snet-public-nwl-346" })
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

# NEU: zweites Subnetz in anderer AZ
resource "aws_subnet" "snet-public-nwl-346b" {
  vpc_id                  = aws_vpc.vpc-nwl-346.id
  tags                    = merge(var.tags, { Name = "snet-public-nwl-346b" })
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_network_acl" "acl-public-nwl-346" {
  vpc_id     = aws_vpc.vpc-nwl-346.id
  subnet_ids = [aws_subnet.snet-public-nwl-346.id, aws_subnet.snet-public-nwl-346b.id] # beide Subnetze

  egress {
    to_port    = 0
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    from_port  = 0
    cidr_block = "0.0.0.0/0"
  }

  ingress {
    protocol   = "icmp"
    rule_no    = 100
    action     = "allow"
    from_port  = 0
    to_port    = 0
    icmp_type  = -1
    icmp_code  = -1
    cidr_block = "0.0.0.0/0"
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    from_port  = 22
    to_port    = 22
    cidr_block = "0.0.0.0/0"
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    from_port  = 80
    to_port    = 80
    cidr_block = "0.0.0.0/0"
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 130   # war vorher auch 120 -> Konflikt behoben
    action     = "allow"
    from_port  = 443
    to_port    = 443
    cidr_block = "0.0.0.0/0"
  }

  tags = {
    Name = "acl-public-nwl-346"
  }
}

resource "aws_internet_gateway" "internet_gw" {
  vpc_id = aws_vpc.vpc-nwl-346.id

  tags = {
    Name = "igw-nwl-346"
  }
}

resource "aws_eip" "eip-public-nwl-346" {
  tags = merge(var.tags, { Name = "eip-public-nwl-346" })
}

resource "aws_nat_gateway" "ngw-public-nwl-346" {
  tags              = merge(var.tags, { Name = "ngw-public-nwl-346" })
  subnet_id         = aws_subnet.snet-public-nwl-346.id
  connectivity_type = "public"
  allocation_id     = aws_eip.eip-public-nwl-346.id
}

resource "aws_route_table" "rt-public-nwl-346" {
  vpc_id = aws_vpc.vpc-nwl-346.id
  tags   = merge(var.tags, { Name = "rt-public-nwl-346" })

  route {
    gateway_id = aws_internet_gateway.internet_gw.id
    cidr_block = "0.0.0.0/0"
  }
}

# Route Table Association für BEIDE Subnetze
resource "aws_route_table_association" "rt_association" {
  subnet_id      = aws_subnet.snet-public-nwl-346.id
  route_table_id = aws_route_table.rt-public-nwl-346.id
}

resource "aws_route_table_association" "rt_association_b" {
  subnet_id      = aws_subnet.snet-public-nwl-346b.id
  route_table_id = aws_route_table.rt-public-nwl-346.id
}