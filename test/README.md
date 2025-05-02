# Basecamp Tests

This directory contains tests for the Basecamp OCaml client library. There are two types of tests:

1. **Model Tests** - Verify that the `Model` module correctly parses and serializes JSON data from the Basecamp API
2. **Client Tests** - Test the actual API client functionality against the Basecamp API

## Model Tests

These tests verify that the JSON parsing and serialization functions work correctly.

### Running the Model Tests

```bash
dune runtest
```

This will:
1. Run the test program that parses test JSON files and outputs the raw JSON
2. Compare the output to the expected output defined in `test_model.expected`
3. Show a diff if there are any differences

### Updating Expected Output

If you've made intentional changes to the model or tests and need to update the expected output:

```bash
dune promote
```

This will update the `test_model.expected` file with the current output of the tests.

### Test Data

The test data for model tests is stored in JSON files in the `test/json` directory:

- `person.json` - Single person data
- `people.json` - Array of people
- `project.json` - Project data
- `todolist.json` - TodoList data
- `todo.json` - Todo data
- `todoset.json` - TodoSet data
- `invalid.json` - Invalid JSON for error testing

## Client Tests

The client tests exercise the actual API client against the Basecamp API. These tests require valid Basecamp credentials to run.

### Running the Client Tests

First, create a `test_client.json` file with your credentials:

```json
{
  "organization_id": 123456,
  "client_id": "your_client_id",
  "client_secret": "your_client_secret",
  "refresh_token": "your_refresh_token"
}
```

Then run the client tests:

```bash
cd test && dune exec -- ./test_client.exe
```

This will perform a series of API calls to Basecamp and verify the responses.

## Adding New Tests

### For Model Tests

1. Add a new JSON file to `test/json`
2. Update `test_model.ml` to parse the new file and output the results
3. Run the tests and promote the changes if they're correct

### For Client Tests

1. Update `test_client.ml` to add new test cases
2. Run the client tests to verify the new functionality

## Troubleshooting

### Model Tests

If the model tests are failing, check:

1. The JSON files match the expected structure
2. The `Model` module is correctly parsing the JSON
3. The JSON output matches the expected format in `test_model.expected`

### Client Tests

If the client tests are failing, check:

1. Your credentials in `test_client.json` are correct
2. You have the necessary permissions in Basecamp
3. The network connection to Basecamp API is working
4. The API hasn't changed in ways that break the client
