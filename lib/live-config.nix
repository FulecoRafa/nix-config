{ }:

{
  package,
  name,
  source,
  target,
  repositoryPath ? null,
}:

package
// {
  liveConfig = {
    inherit
      name
      repositoryPath
      source
      target
      ;
  };
}
