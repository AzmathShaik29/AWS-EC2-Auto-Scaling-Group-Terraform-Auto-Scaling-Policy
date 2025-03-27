# Go through the below troubleshooting process, if you encountered any issues while implementing this task.

## Prerequisites

1. Install AWS CLI on top of EC2 instance
2. AWS configure 

Install AWS CLI Manually (Recommended)
If awscli is not available via apt, install it manually:

Step 1: Download the AWS CLI Installer
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
```
Step 2: Install Unzip (if not installed)
```bash
sudo apt install unzip -y
```
Step 3: Unzip and Install AWS CLI
```bash
unzip awscliv2.zip
sudo ./aws/install
```
Step 4: Verify the Installation
```bash
aws --version
```

Check if EC2 is Sending Metrics
Run the following AWS CLI command to check if metrics are being reported:

```bash
aws cloudwatch list-metrics --namespace "AWS/EC2" --metric-name "CPUUtilization"
```
## Fixing CloudWatch Alarm Issue

1. Check if CloudWatch Alarm is Attached to the ASG
Run:

```bash
aws cloudwatch describe-alarms --query "MetricAlarms[*].{Name:AlarmName,Metric:MetricName,Dimensions:Dimensions}"
```

Check if:
- The alarm name matches what you expect.
- The dimensions include AutoScalingGroupName = "terraform-2025032712345678910".

If the ASG name is missing or incorrect, you may need to recreate the alarm.

Step 1: Delete the Incorrect Alarms
Run:

```bash
aws cloudwatch delete-alarms --alarm-names "increase-ec2-alarm" "reduce-ec2-alarm"
```
This removes the alarms that have no dimensions.

Step 2: Create the Correct Alarms
Now, create alarms that monitor the CPUUtilization of your ASG.

Alarm to Increase Instances (Scale Up)
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "increase-ec2-alarm" \
  --metric-name "CPUUtilization" \
  --namespace "AWS/EC2" \
  --statistic "Average" \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 70 \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --dimensions Name=AutoScalingGroupName,Value=terraform-20250327081805056400000007 \
  --alarm-actions "arn:aws:autoscaling:region:account-id:scalingPolicy:policy-id:autoScalingGroupName/terraform-20250327081805056400000007:policyName/MyASG-ScaleUp"
```
# Alarm to Decrease Instances (Scale Down)
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "reduce-ec2-alarm" \
  --metric-name "CPUUtilization" \
  --namespace "AWS/EC2" \
  --statistic "Average" \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 40 \
  --comparison-operator "LessThanOrEqualToThreshold" \
  --dimensions Name=AutoScalingGroupName,Value=terraform-20250327081805056400000007 \
  --alarm-actions "arn:aws:autoscaling:region:account-id:scalingPolicy:policy-id:autoScalingGroupName/terraform-20250327081805056400000007:policyName/MyASG-ScaleDown"
```
Step 3: Verify That the Alarms Have the Correct Dimensions
```bash
aws cloudwatch describe-alarms --query "MetricAlarms[*].{Name:AlarmName,Metric:MetricName,Dimensions:Dimensions}"
```
Expected Output:
```bash
[
    {
        "Name": "increase-ec2-alarm",
        "Metric": "CPUUtilization",
        "Dimensions": [
            {
                "Name": "AutoScalingGroupName",
                "Value": "terraform-2025032712345678910"
            }
        ]
    },
    {
        "Name": "reduce-ec2-alarm",
        "Metric": "CPUUtilization",
        "Dimensions": [
            {
                "Name": "AutoScalingGroupName",
                "Value": "terraform-2025032712345678910"
            }
        ]
    }
]
```
- After this you may encounter the issue related to region, account id and arn. For that kindly follow the below command

Get the correct scaling policy ARN for your Auto Scaling Group:
```bash
aws autoscaling describe-policies --auto-scaling-group-name terraform-20250327123456789107 --query "ScalingPolicies[*].PolicyARN" --region eu-west-3
```

CloudWatch alarm for Scale-Up
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "increase-ec2-alarm" \
  --metric-name "CPUUtilization" \
  --namespace "AWS/EC2" \
  --statistic "Average" \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 70 \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --dimensions Name=AutoScalingGroupName,Value=terraform-20250327081805056400000007 \
  --alarm-actions "arn:aws:autoscaling:eu-west-3:12345678910:scalingPolicy:1d56bb04-2r92-4564-n5e0-012310dbe664:autoScalingGroupName/terraform-20250327012345678910:policyName/increase-ec2"
```

CloudWatch alarm for Scale-Down
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "reduce-ec2-alarm" \
  --metric-name "CPUUtilization" \
  --namespace "AWS/EC2" \
  --statistic "Average" \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 40 \
  --comparison-operator "LessThanOrEqualToThreshold" \
  --dimensions Name=AutoScalingGroupName,Value=terraform-20250327081805056400000007 \
  --alarm-actions "arn:aws:autoscaling:eu-west-3:1234567910:scalingPolicy:7e6jf2dd-5nbb-4mmf-844c-f44551066674:autoScalingGroupName/terraform-20250327012345678910:policyName/reduce-ec2"
```

### PROCESS 1
1. To increase the CPU utilization of your EC2 instance above 70% and trigger the CloudWatch alarm, you can run a stress test using the stress or stress-ng tool. Follow these steps:

Step 1: Install stress-ng
Run the following command in your EC2 instance terminal:

```bash
sudo yum install -y epel-release
sudo yum install -y stress-ng
```
For Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y stress-ng
```
Step 2: Run CPU Stress Test
Now, run the following command to utilize all available CPU cores at full capacity:

```bash
stress-ng --cpu 4 --cpu-load 100 --timeout 300s
```
- cpu 4: Uses 4 CPU cores (adjust according to your instance type).
- cpu-load 100: Increases load to 100% on each core.
- timeout 300s: Runs the stress test for 5 minutes (adjust as needed).

Step 3: Monitor CPU Usage
Check CPU utilization in real-time:

```bash
top
```
Or use:

```bash
htop
```
Step 4: Wait for CloudWatch Alarm to Trigger
- The CloudWatch alarm is configured to trigger when CPU utilization is above 70% for 2 evaluation periods (each 120 seconds).
- Wait for about 4-5 minutes for the alarm to be evaluated and trigger Auto Scaling.

Stopping the Load Test
If you want to stop the load manually, run:

```bash
pkill stress-ng
```

### PROCESS 2

# Simulate High CPU Usage
```bash
yes > /dev/null &
yes > /dev/null &
yes > /dev/null &
```

This will use 4 CPU cores at 100%. To stop it, run:

```bash
killall yes
```
