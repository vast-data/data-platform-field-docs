#!/bin/bash
set -e

# This script is the main entry point for the Docker container.
# It validates environment variables and then executes the test script.

# --- Function to display usage information ---
show_usage() {
    echo "Hadoop S3A Tester"
    echo "-------------------"
    echo "This container runs a suite of functional tests against an S3 endpoint using Hadoop's S3A connector."
    echo ""
    echo "Usage: docker run --rm -it \\"
    echo "  -e S3_ENDPOINT=<your-s3-endpoint> \\"
    echo "  -e S3_ACCESS_KEY=<your-access-key> \\"
    echo "  -e S3_SECRET_KEY=<your-secret-key> \\"
    echo "  -e S3_TEST_BUCKET=<s3a://your-bucket-name> \\"
    echo "  <image_name>"
    echo ""
    echo "Required Environment Variables:"
    echo "  S3_ENDPOINT:    The full URL of your S3-compatible storage (e.g., http://s3.vastdata.com:80)."
    echo "  S3_ACCESS_KEY:  The access key for your S3 user."
    echo "  S3_SECRET_KEY:  The secret key for your S3 user."
    echo "  S3_TEST_BUCKET: The S3A URI for the bucket to use for testing (e.g., s3a://test-bucket)."
    echo ""
    echo "Optional Environment Variables:"
    echo "  S3_SSL_ENABLED: Set to 'true' or 'false' (default: false). Determines if SSL/TLS is used."
    echo ""
}

# --- Main execution logic ---

# If the first argument is '--help' or '-h', show usage and exit.
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_usage
    exit 0
fi

# Check for the presence of all required environment variables.
if [ -z "$S3_ENDPOINT" ] || [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_SECRET_KEY" ] || [ -z "$S3_TEST_BUCKET" ]; then
    echo "Error: One or more required environment variables are not set."
    echo ""
    show_usage
    exit 1
fi

# Inform the user that the tests are starting.
echo "All required environment variables are set. Starting the S3A functional tests..."
echo "--------------------------------------------------------------------------------"

# Execute the main test script, passing all arguments to it.
/run-s3a-tests.sh "$@"

exit $?

