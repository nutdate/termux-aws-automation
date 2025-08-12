#!/data/data/com.termux/files/usr/bin/zsh
# AWS Mega Inventory - Full AWS Resource Scan
# Author: nutdata automation
# Requires: aws-cli, jq, git

# --- Load Environment ---
source "$HOME/.zshrc"

# --- Variables ---
GIT_MAIN_REPO_DIR="$HOME/termux-aws-automation"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_DIR="$GIT_MAIN_REPO_DIR/aws-reports"
JSON_FILE="$REPORT_DIR/aws_inventory_$TIMESTAMP.json"
MD_FILE="$REPORT_DIR/aws_inventory_$TIMESTAMP.md"
mkdir -p "$REPORT_DIR"

echo "✅ Zsh Environment Loaded. AWS Account: $AWS_ACCOUNT_ID"
echo "🚀 Starting AWS Mega Inventory..."
echo "Region: $AWS_DEFAULT_REGION"
echo "Time: $(date)"
echo "{}" > "$JSON_FILE"

# Markdown section function
md_section() { echo -e "\n## $1\n" >> "$MD_FILE"; }

# --- Function to Save JSON & Markdown ---
save_data() {
    local name="$1"
    local jq_key="$2"
    local data="$3"
    local jq_filter="$4"
    jq --argjson val "$data" ".$jq_key = \$val" "$JSON_FILE" > tmp.$$.json && mv tmp.$$.json "$JSON_FILE"
    md_section "$name"
    if [ -z "$(echo "$data" | jq "$jq_filter")" ]; then
        echo "No $name found." >> "$MD_FILE"
    else
        echo "$data" | jq -r "$jq_filter" >> "$MD_FILE"
    fi
}

# --- AWS Data Fetch ---
echo "🔎 Fetching EC2 Instances..."
EC2_DATA=$(aws ec2 describe-instances --region "$AWS_DEFAULT_REGION" \
    --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,PublicIpAddress,KeyName,Tags[?Key==`Name`].Value | [0]]' \
    --output json)
save_data "EC2 Instances" "ec2" "$EC2_DATA" '
  .[]? | .[]? |
  "**ID:** " + .[0] + " | " +
  "**Name:** " + (.[5] // "N/A") + " | " +
  "**Type:** " + .[1] + " | " +
  "**State:** " + .[2] + " | " +
  "**Public IP:** " + (.[3] // "N/A") + " | " +
  "**Key Pair:** " + (.[4] // "N/A")'

echo "🗂 Fetching S3 Buckets..."
S3_DATA=$(aws s3api list-buckets --output json)
save_data "S3 Buckets" "s3" "$S3_DATA" '.Buckets[]? | "**Name:** \(.Name) | **Created:** \(.CreationDate)"'

echo "🗄 Fetching RDS Instances..."
RDS_DATA=$(aws rds describe-db-instances --region "$AWS_DEFAULT_REGION" --output json)
save_data "RDS Instances" "rds" "$RDS_DATA" '.DBInstances[]? | "**ID:** \(.DBInstanceIdentifier) | **Engine:** \(.Engine) | **Status:** \(.DBInstanceStatus)"'

echo "⚙️ Fetching Lambda Functions..."
LAMBDA_DATA=$(aws lambda list-functions --region "$AWS_DEFAULT_REGION" --output json)
save_data "Lambda Functions" "lambda" "$LAMBDA_DATA" '.Functions[]? | "**Name:** \(.FunctionName) | **Runtime:** \(.Runtime) | **Last Modified:** \(.LastModified)"'

echo "👤 Fetching IAM Users..."
IAM_DATA=$(aws iam list-users --output json)
save_data "IAM Users" "iam" "$IAM_DATA" '.Users[]? | "**Name:** \(.UserName) | **Created:** \(.CreateDate)"'

# --- New Sections ---
echo "🌐 Fetching VPCs..."
VPC_DATA=$(aws ec2 describe-vpcs --region "$AWS_DEFAULT_REGION" --output json)
save_data "VPCs" "vpcs" "$VPC_DATA" '.Vpcs[]? | "**ID:** \(.VpcId) | **CIDR:** \(.CidrBlock) | **State:** \(.State)"'

echo "🛡 Fetching Security Groups..."
SG_DATA=$(aws ec2 describe-security-groups --region "$AWS_DEFAULT_REGION" --output json)
save_data "Security Groups" "security_groups" "$SG_DATA" '.SecurityGroups[]? | "**ID:** \(.GroupId) | **Name:** \(.GroupName) | **Description:** \(.Description)"'

echo "💾 Fetching EBS Volumes..."
EBS_DATA=$(aws ec2 describe-volumes --region "$AWS_DEFAULT_REGION" --output json)
save_data "EBS Volumes" "ebs" "$EBS_DATA" '.Volumes[]? | "**ID:** \(.VolumeId) | **Size:** \(.Size)GiB | **State:** \(.State)"'

echo "📡 Fetching Elastic IPs..."
EIP_DATA=$(aws ec2 describe-addresses --region "$AWS_DEFAULT_REGION" --output json)
save_data "Elastic IPs" "elastic_ips" "$EIP_DATA" '.Addresses[]? | "**Public IP:** \(.PublicIp) | **Allocation ID:** \(.AllocationId)"'

echo "🌍 Fetching CloudFront Distributions..."
CF_DATA=$(aws cloudfront list-distributions --output json)
save_data "CloudFront Distributions" "cloudfront" "$CF_DATA" '.DistributionList.Items[]? | "**ID:** \(.Id) | **Domain:** \(.DomainName) | **Status:** \(.Status)"'

echo "📂 Fetching DynamoDB Tables..."
DDB_TABLES=$(aws dynamodb list-tables --output json)
save_data "DynamoDB Tables" "dynamodb" "$DDB_TABLES" '.TableNames[]? | "**Table:** \(.)"'

echo "🐳 Fetching ECS Clusters..."
ECS_CLUSTERS=$(aws ecs list-clusters --output json)
save_data "ECS Clusters" "ecs_clusters" "$ECS_CLUSTERS" '.clusterArns[]? | "**Cluster ARN:** \(.)"'

echo "⏰ Fetching CloudWatch Alarms..."
CW_ALARMS=$(aws cloudwatch describe-alarms --output json)
save_data "CloudWatch Alarms" "cloudwatch_alarms" "$CW_ALARMS" '.MetricAlarms[]? | "**Name:** \(.AlarmName) | **State:** \(.StateValue)"'

echo "📣 Fetching SNS Topics..."
SNS_TOPICS=$(aws sns list-topics --output json)
save_data "SNS Topics" "sns_topics" "$SNS_TOPICS" '.Topics[]? | "**Topic ARN:** \(.TopicArn)"'

echo "📬 Fetching SQS Queues..."
SQS_QUEUES=$(aws sqs list-queues --output json)
save_data "SQS Queues" "sqs_queues" "$SQS_QUEUES" '.QueueUrls[]? | "**Queue URL:** \(.)"'

echo "🌏 Fetching Route53 Hosted Zones..."
ROUTE53_ZONES=$(aws route53 list-hosted-zones --output json)
save_data "Route53 Hosted Zones" "route53" "$ROUTE53_ZONES" '.HostedZones[]? | "**Name:** \(.Name) | **ID:** \(.Id)"'

# --- Commit & Push to GitHub ---
echo "📤 Saving reports to GitHub..."
cd "$GIT_MAIN_REPO_DIR"
git add aws-reports/
git commit -m "AWS Mega Inventory report - $TIMESTAMP"
git push origin $(git rev-parse --abbrev-ref HEAD)

echo "✅ AWS Mega Inventory complete. Reports saved to:"
echo "   - $JSON_FILE"
echo "   - $MD_FILE"
