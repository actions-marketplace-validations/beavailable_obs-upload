# obs-upload
Github Action to upload files to OBS (Open Build Service).

**Note** that it'll remove all files in a package before uploading new files.

## Inputs
**apiurl**  
Optional, default to `https://api.opensuse.org`.

**username**  
Required.

**password**  
Required.

**project**  
Required.

**package**  
Required.

**files**  
Required, space-separated glob patterns.

## Example
```yml
steps:
  - name: Upload to OBS
    uses: beavailable/obs-upload@main
    with:
      username: test-name
      password: ${{ secrets.OBS_PASSWORD }}
      project: test-project
      package: test-package
      files: ./*.txt ./*.tar.xz
```
