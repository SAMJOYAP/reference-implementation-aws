# ${{ values.name }}

> EC2 instance managed by Terraform

## 📋 Configuration

- **Instance Type**: `${{ values.instanceType }}`
- **Region**: `${{ values.region }}`
- **Managed by**: Terraform + GitHub Actions

## 🚀 Deployment

### Automatic Deployment

This repository uses **GitHub Actions** for automatic deployment:

```
Push to main → GitHub Actions → Terraform Apply → EC2 Created
```

### Manual Deployment

```bash
# Configure AWS credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="${{ values.region }}"

# Initialize Terraform
cd terraform
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply
```

## 📊 View Resources

### AWS Console

```bash
# Get instance ID
terraform output instance_id

# Open in AWS Console
open "https://console.aws.amazon.com/ec2/v2/home?region=${{ values.region }}#Instances:"
```

### CLI

```bash
# Describe instance
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${{ values.name }}" \
  --region ${{ values.region }}
```

## 🔧 Modify Configuration

Edit `terraform/variables.tf` or `terraform/main.tf`:

```hcl
variable "instance_type" {
  default = "${{ values.instanceType }}"  # Change this
}
```

Then commit and push:

```bash
git add terraform/
git commit -m "Update instance type"
git push origin main
```

GitHub Actions will automatically apply changes.

## 🗑️ Destroy Resources

```bash
cd terraform
terraform destroy
```

Or use GitHub Actions with manual trigger.

## 📚 Learn More

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [Backstage Documentation](https://backstage.io/docs)

---

Created with ❤️ by Backstage
