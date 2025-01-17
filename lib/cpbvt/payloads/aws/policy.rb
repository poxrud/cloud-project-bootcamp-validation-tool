require 'fileutils'
require 'yaml'

class Cpbvt::Payloads::Aws::Policy
  include Cpbvt::Payloads::Aws::Policies::Acm
  include Cpbvt::Payloads::Aws::Policies::Apigatewayv2
  include Cpbvt::Payloads::Aws::Policies::Cloudformation
  include Cpbvt::Payloads::Aws::Policies::Cloudfront
  include Cpbvt::Payloads::Aws::Policies::Codebuild
  include Cpbvt::Payloads::Aws::Policies::Codepipeline
  include Cpbvt::Payloads::Aws::Policies::CognitoIdp
  include Cpbvt::Payloads::Aws::Policies::Dynamodb
  include Cpbvt::Payloads::Aws::Policies::Dynamodbstreams
  include Cpbvt::Payloads::Aws::Policies::Ec2
  include Cpbvt::Payloads::Aws::Policies::Ecr
  include Cpbvt::Payloads::Aws::Policies::Ecs
  include Cpbvt::Payloads::Aws::Policies::Elbv2
  include Cpbvt::Payloads::Aws::Policies::Lambda
  include Cpbvt::Payloads::Aws::Policies::Rds
  include Cpbvt::Payloads::Aws::Policies::Route53
  include Cpbvt::Payloads::Aws::Policies::S3api
  include Cpbvt::Payloads::Aws::Policies::Servicediscovery

  @@permissions = []

  def self.add region, command, general_params, specific_params
    specific_params[:aws_account_id] = general_params.target_aws_account_id
    specific_params[:region] = region if region != 'global'

    permissions = self.send command, **specific_params
    permissions = [permissions] if permissions.is_a?(Hash)
    if region != 'global'
      permissions.map! do |permission|
        self.condition_region permission, region
      end
    end
    permissions.each do |permission|
      @@permissions.push permission
    end
  end

  def self.condition_region permission, region
    permission['Condition'] ||= {}
    permission['Condition']['StringEquals'] ||= {}
    permission['Condition']['StringEquals']["aws:RequestedRegion"] = region
    permission
  end

  def self.generate! general_params
    path = File.join(
      File.dirname(File.expand_path(__FILE__)),
      "#{general-params.run_uuid}-cross-account-role-template.yaml"
    )
    cfn_template = YAML.load_file(path)

    # Policy exceeding the 6144 characters limit can't be saved. 
    max_count = 4000
    current_count = 0
    i = 0

    permissions_chunk = []

    @@permissions.each_with_index do |permission,index|
      json = permission.to_json
      if (current_count + json.size) > max_count || @@permissions.size-1 == index
        if @@permissions.size-1 == index
          permissions_chunk.push permission
        end
        #add another
        policy_template = {
          "PolicyName" => "BootcampPolicy#{i}",
          "PolicyDocument" => {
            "Version" => "2012-10-17",
            "Statement" => []
          }
        }
        cfn_template['Resources']['CrossAccountRole']['Properties']['Policies'].push(policy_template)
        cfn_template['Resources']['CrossAccountRole']['Properties']['Policies'][i]['PolicyDocument']['Statement'] = permissions_chunk

        i += 1
        current_count = 0
        permissions_chunk = []
      else
        #add to existing
        current_count += json.size
        permissions_chunk.push permission
      end
    end


    output_path = File.join(
      general_params.output_path,
      general_params.project_scope,
      "user-#{general_params.user_uuid}",
      "#{general_params.run_uuid}-cross-account.yaml"
    )

    dirpath = File.dirname output_path
    FileUtils.mkdir_p(dirpath)

    File.open(output_path, 'w') do |f|
      f.write(cfn_template.to_yaml)
    end
  end
end
