require 'fileutils'

module Cpbvt::Payloads::Aws::Runner
  def self.run command, attrs
    output_file = Cpbvt::Payloads::Aws::output_file(
      user_uuid: attrs.user_uuid,
      project_scope: attrs.project_scope,
      region: attrs.region, 
      output_path: attrs.output_path,
      filename: attrs.filename
    )

    output_key = Cpbvt::Uploader::output_key(
      user_uuid: attrs.user_uuid,
      project_scope: attrs.project_scope,
      region: attrs.region, 
      filename: attrs.filename
    )

    command = Cpbvt::Payloads::Aws::Commands.execute_with_send(
      command,
      output_file: output_file,
      region: attrs.region
    )

    Cpbvt::Payloads::Aws.execute command
    # upload json file to s3
    Cpbvt::Uploader.run(
      file_path: attrs.file_path, 
      object_key: attrs.object_key,
      aws_region: attrs.aws_region,
      aws_access_key_id: attrs.aws_access_key_id,
      aws_secret_access_key: attrs.aws_secret_access_key,
      payloads_bucket: attrs.payloads_bucket
    )
  end

  # create the path to where the json file will be downloaded
  def self.output_file user_uuid:, 
                       project_scope:,
                       region:,
                       output_path:,
                       filename:
    value = File.join(
      output_path, 
      project_scope, 
      user_uuid, 
      region, 
      filename
    )

    # create the folder for the downloaded json if it doesn't exist
    FileUtils.mkdir_p File.dirname(value)

    # print the desination of the outputed json
    puts "[Output File]"
    puts value

    return value
  end

  def self.execute command
    # print the command so we know what is running
    puts "[Executing...]"
    puts command
    # run the command which will download the json
    system command
  end
end

module Cpbvt::Payloads::Aws::Commands
  def self.describe_vpcs(region:, output_file:)
    # format the AWS CLI command to be a single line
    command = <<~COMMAND.strip.gsub("\n", " ")
  aws ec2 describe-vpcs \
  --region #{region} \
  > #{output_file}
    COMMAND
  end
end