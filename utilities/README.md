# Overview

This directory contains sample files that can be used as part of the deployment.

# File List
* viya_34_0_vars.yml
  * Template of a vars.yml file for SAS Viya 3.4 for Linux

# How to Use

## vars.yml
```
cp --verbose utilities/viya_34_0_vars.yml viya-programming/viya-single-container/vars.yml
vi viya-programming/viya-single-container/vars.yml
# Update the LICENSE_FILENAME and LICENSE_COMPOSITE_FILENAME variables
# Edit the CAS and SAS Foundation configuration as needed
# save the file

# build the image
cd viya-programming/viya-single-container
docker build --file Dockerfile . -t viya-single-container
```

# Copyright

Copyright 2018 SAS Institute Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

&nbsp;&nbsp;&nbsp;&nbsp;https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
