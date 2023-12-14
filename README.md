# A two-tier architecture for a single-page application

The purpose of this project is to quickly deploy a simple, two-tier architecture in the AWS cloud for a single-page application using IaC. The solution is written in HCL, Terraform's language.

The components involved are the following:

* VPC
* EC2
* Auto-scaling group (ASG)
* Application load balancer (ALB)
* Security groups

## Architectural diagram
![Diagram](images/diagram.png)


## Usage
This code assumes that you have already Terraform installed locally. For instructions on how to install Terraform, please refer to Hashicorp's documentation [1].

## References
[1]: https://developer.hashicorp.com/terraform/install

  
