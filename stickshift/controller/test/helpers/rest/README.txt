REST API Version Compatibility:
-------------------------------
- These files are helper scripts for rest_api_test.rb & rest_api_nolinks_test.rb unit tests.
- These tests will ensure supported versions of REST APIs are working correctly.
  For every supported version of REST api, it validates consistency of these cases:
   * Request/Response version
   * Request parameters
   * Request default values
   * Response status
   * Response type
   * Response parameters
   * Response links

NOTE: For supported REST api version 'X', v<X>/api_model_v<X>, v<X>/api_v<X> has expected request/response format. 
      If the rest api unit test fails for older version, we have to fix the broker code and *NOT* the unit tests.
