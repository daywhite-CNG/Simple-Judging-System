const { defineConfig } = require("@vue/cli-service");
const MonacoWebpackPlugin = require("monaco-editor-webpack-plugin");

module.exports = defineConfig({
  transpileDependencies: true,
  // [本地部署修改] 开启 SPA 路由回退：否则 /user/register、/questions 等
  // 直接输入网址或刷新会返回 404（浏览器内点链接跳转才正常）
  devServer: {
    historyApiFallback: {
      disableDotRule: true,
    },
  },
  chainWebpack(config) {
    config.plugin("monaco").use(new MonacoWebpackPlugin());
  },
});
