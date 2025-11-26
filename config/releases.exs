import Config

# In this file, we run each command with `System.cmd!/2` and inspect the
# output to ensure the commands are working as expected and to help
# debug issues.

# We set the PHX_SERVER environment variable to true to start the Phoenix
# server when the release is started.
System.put_env("PHX_SERVER", "true")

# We also set the SECRET_KEY_BASE environment variable if it's not already set.
# This is important for production deployments.
if System.get_env("SECRET_KEY_BASE") == nil do
  System.put_env(
    "SECRET_KEY_BASE",
    System.cmd!("mix", ["phx.gen.secret"], stderr_to_stdout: true)
  )
end
