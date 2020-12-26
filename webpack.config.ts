import * as path from 'path';
import * as webpack from 'webpack';
import {merge} from 'webpack-merge';
import ClosurePlugin from "closure-webpack-plugin";
import CopyWebpackPlugin from "copy-webpack-plugin";
import HTMLWebpackPlugin from "html-webpack-plugin";
import {CleanWebpackPlugin} from "clean-webpack-plugin";

// Production CSS assets - separate, minimised file
import MiniCssExtractPlugin from "mini-css-extract-plugin";
import OptimizeCSSAssetsPlugin from "optimize-css-assets-webpack-plugin";

const config: webpack.Configuration = {
  mode: 'production',
  entry: './foo.js',
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'foo.bundle.js'
  }
};

export default config;

var MODE =
    process.env.npm_lifecycle_event === "prod" ? "production" : "development";
var withDebug = !process.env["npm_config_nodebug"] && MODE === "development";
// this may help for Yarn users
// var withDebug = !npmParams.includes("--nodebug");
console.log(
    "\x1b[36m%s\x1b[0m",
    `** elm-webpack-starter: mode "${MODE}", withDebug: ${withDebug}\n`
);

var common : webpack.Configuration = {
    mode: "development",
    entry: "./src/index.ts",
    output: {
        path: path.join(__dirname, "dist"),
        publicPath: "/",
        // FIXME webpack -p automatically adds hash when building for production
        filename: MODE === "production" ? "[name]-[hash].js" : "index.js"
    },
    plugins: [
        new HTMLWebpackPlugin({
            // Use this template to get basic responsive meta tags
            template: "src/index.html",
            // inject details of output file at end of body
            inject: "body"
        })
    ],
    resolve: {
        modules: [path.join(__dirname, "src"), "node_modules"],
        extensions: [".js", ".elm", ".css", ".png"]
    },
    module: {
        rules: [
            {
                test: /\.ts$/,
                exclude: [/node_modules/, /webpack.config.ts/],
                use: "ts-loader"
            },
            {
                test: /\.css$/,
                exclude: [/elm-stuff/, /node_modules/],
                use: ["style-loader", "css-loader?url=false"]
            },
            {
                test: /\.woff(2)?(\?v=[0-9]\.[0-9]\.[0-9])?$/,
                exclude: [/elm-stuff/, /node_modules/],
                use: {
                    loader: "url-loader",
                    options: {
                        limit: 10000,
                        mimetype: "application/font-woff"
                    }
                }
            },
            {
                test: /\.(ttf|eot|svg)(\?v=[0-9]\.[0-9]\.[0-9])?$/,
                exclude: [/elm-stuff/, /node_modules/],
                loader: "file-loader"
            },
            {
                test: /\.(jpe?g|png|gif|svg)$/i,
                exclude: [/elm-stuff/, /node_modules/],
                loader: "file-loader"
            }
        ]
    }
};

if (MODE === "development") {
    module.exports = merge(common, {
        optimization: {
            // Prevents compilation errors causing the hot loader to lose state
            emitOnErrors: false
        },
        module: {
            rules: [
                {
                    test: /\.elm$/,
                    exclude: [/elm-stuff/, /node_modules/],
                    use: [
                        {loader: "elm-hot-webpack-loader"},
                        {
                            loader: "elm-webpack-loader",
                            options: {
                                // add Elm's debug overlay to output
                                debug: withDebug
                            }
                        }
                    ]
                }
            ]
        },
        devServer: {
            inline: true,
            stats: "errors-only",
            contentBase: path.join(__dirname, "src/assets"),
            historyApiFallback: true,
            // feel free to delete this section if you don't need anything like this
            before(app) {
                // on port 3000
                app.get("/test", function (req, res) {
                    res.json({result: "OK"});
                });
            }
        }
    });
}

if (MODE === "production") {
    module.exports = merge(common, {
        optimization: {
            minimizer: [
                new ClosurePlugin(
                    {mode: "STANDARD"},
                    {
                        // compiler flags here
                        //
                        // for debugging help, try these:
                        //
                        // formatting: 'PRETTY_PRINT',
                        // debug: true
                        // renaming: false
                    }
                ),
                new OptimizeCSSAssetsPlugin({})
            ]
        },
        plugins: [
            // Delete everything from output-path (/dist) and report to user
            new CleanWebpackPlugin({
                verbose: true,
                dry: false
            }),
            // Copy static assets
            new CopyWebpackPlugin({
                patterns: [
                    {
                        from: "src/assets"
                    }
                ]
            }),
            new MiniCssExtractPlugin({
                // Options similar to the same options in webpackOptions.output
                // both options are optional
                filename: "[name]-[hash].css"
            })
        ],
        module: {
            rules: [
                {
                    test: /\.elm$/,
                    exclude: [/elm-stuff/, /node_modules/],
                    use: {
                        loader: "elm-webpack-loader",
                        options: {
                            optimize: true
                        }
                    }
                },
                {
                    test: /\.css$/,
                    exclude: [/elm-stuff/, /node_modules/],
                    use: [
                        MiniCssExtractPlugin.loader,
                        "css-loader?url=false"
                    ]
                },
                {
                    test: /\.scss$/,
                    exclude: [/elm-stuff/, /node_modules/],
                    use: [
                        MiniCssExtractPlugin.loader,
                        "css-loader?url=false",
                        "sass-loader"
                    ]
                }
            ]
        }
    });
}
