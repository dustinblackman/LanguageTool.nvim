/*
 * This Java source file was generated by the Gradle 'init' task.
 */
package LangTool.neovim.java;

import java.net.Socket;
import java.io.IOException;
import java.io.File;
import java.net.UnknownHostException;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Executors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ensarsarajcic.neovim.java.api.NeovimApi;
import com.ensarsarajcic.neovim.java.api.NeovimStreamApi;
import com.ensarsarajcic.neovim.java.api.types.api.ClientType;
import com.ensarsarajcic.neovim.java.api.types.api.ClientVersionInfo;
import com.ensarsarajcic.neovim.java.api.types.msgpack.NeovimJacksonModule;
import com.ensarsarajcic.neovim.java.corerpc.client.RPCClient;
import com.ensarsarajcic.neovim.java.corerpc.client.RPCConnection;
import com.ensarsarajcic.neovim.java.corerpc.client.TcpSocketRPCConnection;
import com.ensarsarajcic.neovim.java.corerpc.reactive.ReactiveRPCClient;
import com.ensarsarajcic.neovim.java.handler.NeovimHandlerManager;
import com.ensarsarajcic.neovim.java.handler.NeovimHandlerProxy;
import com.ensarsarajcic.neovim.java.unix.socket.UnixDomainSocketRPCConnection;

public class App {

    public static final Logger logger = LoggerFactory.getLogger(App.class);
    public NeovimApi nvimApi;
    private RPCClient rpcStream;
    private NeovimHandlerManager handlerManager;

    public static void main(String[] args) throws UnknownHostException, IOException, InterruptedException, ExecutionException {

        RPCConnection connection;

        switch (args.length) {
            case 1:
                File socketFile = new File(args[0]);
                App.logger.info("Connecting to " + args[0] + "...");
                connection = new UnixDomainSocketRPCConnection(socketFile);
                break;
            case 2:
                Socket socket = new Socket(args[0], Integer.decode(args[1]));
                App.logger.info(String.format("Connecting to %s:%s...", args[0], args[1]));
                connection = new TcpSocketRPCConnection(socket);
                break;
            default:
                Socket socketDefault = new Socket("127.0.0.1", 1234);
                App.logger.info(String.format("Connecting to default 127.0.0.1:1234..."));
                connection = new TcpSocketRPCConnection(socketDefault);
        }

        App test = new App(connection);
    }

    public App(RPCConnection connection) throws InterruptedException, ExecutionException {
        App.logger.info("Initializing...");
        this.rpcStream = new RPCClient.Builder()
                .withObjectMapper(NeovimJacksonModule.createNeovimObjectMapper()).build();

        ReactiveRPCClient reactiveRPCStreamer = ReactiveRPCClient.createDefaultInstanceWithCustomStreamer(this.rpcStream);

        reactiveRPCStreamer.attach(connection);

        this.nvimApi = new NeovimStreamApi(reactiveRPCStreamer);

        this.handlerManager = new NeovimHandlerManager(
            new NeovimHandlerProxy(Executors.newSingleThreadExecutor())
        );

        this.handlerManager.registerNeovimHandler(new LTCommandHandler(this.nvimApi));
        this.handlerManager.attachToStream(this.rpcStream);

        this.nvimApi.setClientInfo("LanguageTool.nvim", new ClientVersionInfo(0, 1, 0, ""), ClientType.REMOTE, null, null);
    }
}
