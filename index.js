exports.handler = async function(event, context) {
  const message = "Hello, world!";
  return {
    statusCode: 200,
    body: JSON.stringify({ message }),
    headers: {
      "Content-Type": "application/json"
    }
  };
};
