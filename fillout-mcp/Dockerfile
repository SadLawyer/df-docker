FROM node:18-alpine

WORKDIR /app

# Clone the fillout-mcp-server repository
RUN apk add --no-cache git && \
    git clone https://github.com/MCP-Mirror/danielma-tic_fillout-mcp-server.git . && \
    npm install && \
    npm run build

# Expose the MCP server port
EXPOSE 3000

# Run the MCP server
CMD ["node", "dist/index.js"]
