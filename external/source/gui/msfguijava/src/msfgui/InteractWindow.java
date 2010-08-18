/*
 * InteractWindow.java
 *
 * Created on May 15, 2010, 5:46:53 PM
 */
package msfgui;

import java.awt.Font;
import java.awt.event.KeyEvent;
import java.awt.event.KeyListener;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.locks.ReentrantLock;
import javax.swing.JOptionPane;
import org.jdesktop.swingworker.SwingWorker;

/**
 *
 * @author scriptjunkie
 */
public class InteractWindow extends MsfFrame {
	public final ReentrantLock lock = new ReentrantLock();
	public static final char POLL = 'r';
	public static final char STOP_POLLING = 's';
	private final Map session;
	private final RpcConnection rpcConn;
	private final String cmdPrefix;
	private String prompt;
	private Object sid;
	private StringBuffer timerCommand;//synchronized mutable object as command placeholder for polling thread
	private static ArrayList commands;
	private static int currentCommand = 0;
	static{
		commands = new ArrayList();
		commands.add("");
	}

	/** Creates a new window for interacting with shells/meterpreters/consoles */
	public InteractWindow(final RpcConnection rpcConn, final Map session, String type) {
		super(type+" interaction window");
		initComponents();
		this.rpcConn = rpcConn;
		this.session = session;
		sid = session.get("id");
		if(type.equals("console")){ //console stuff
			cmdPrefix = "console.";
			inputField.setFocusTraversalKeysEnabled(false);
			inputField.addKeyListener(new KeyListener(){
				public void keyTyped(KeyEvent ke) {
					if(ke.getKeyChar() == '\t'){
						try{
							Map res = (Map)rpcConn.execute("console.tabs", new Object[]{sid,inputField.getText()});
							Object[] tabs = (Object[])res.get("tabs");
							//one option: use it
							if(tabs.length == 1){
								inputField.setText(tabs[0].toString());
							//more options: display, and use common prefix
							} else if (tabs.length > 1){
								String prefix = tabs[0].toString();
								for(Object o : tabs){
									String s = o.toString();
									int len = Math.min(s.length(), prefix.length());
									for(int i = 0; i < len; i++){
										if(s.charAt(i) != prefix.charAt(i)){
											prefix = prefix.substring(0,i);
											break;
										}
										if(s.length()< prefix.length())
											prefix = s;
									}
									outputArea.append("\n"+o.toString());
								}
								outputArea.append("\n");
								inputField.setText(prefix);
							}
						}catch(MsfException mex){
						}// do nothing on error
					}
				}
				public void keyPressed(KeyEvent ke) {
				}
				public void keyReleased(KeyEvent ke) {
				}
			});
		} else{
			cmdPrefix = "session." + type + "_";
		}
		timerCommand = new StringBuffer(""+POLL);
		prompt = ">>>";

		//start new thread polling for input
		new SwingWorker() {
			protected Object doInBackground() throws Exception {
				long time = 100;
				while (timerCommand.charAt(0) == POLL) {
					if (lock.tryLock() == false) {
						this.publish("locked");
						lock.lock();
						this.publish("unlocked");
					}
					try {
						long start = System.currentTimeMillis();
						Map received = (Map) rpcConn.execute(cmdPrefix+"read", new Object[]{sid});
						time = System.currentTimeMillis() - start;
						if (!received.get("encoding").equals("base64"))
							throw new MsfException("Uhoh. Unknown encoding. Time to update?");
						byte[] decodedBytes = Base64.decode(received.get("data").toString());
						if (decodedBytes.length > 0) {
							outputArea.append(new String(decodedBytes));
							if(decodedBytes[decodedBytes.length-1] != '\n')
								outputArea.append("\n");//cause windows is just like that.
							publish("data");
							publish(received);
						}
					} catch (MsfException ex) {
						if(!ex.getMessage().equals("unknown session"))
							JOptionPane.showMessageDialog(null, ex);
						timerCommand.setCharAt(0, STOP_POLLING);
					}
					lock.unlock();
					try {
						Thread.sleep(100 + (time * 3));// if it takes a long time to get data, ask for it slower
					} catch (InterruptedException iex) {
					}
				}
				return null;
			}
			protected void process(List l){
				for(Object o : l){
					if(o.equals("locked")){
						submitButton.setEnabled(false);
						inputField.setEditable(false);
					}else if(o.equals("unlocked")){
						submitButton.setEnabled(true);
						inputField.setEditable(true);
					}else if(o instanceof Map){
						checkPrompt((Map)o);
					}else{
						outputArea.setCaretPosition(outputArea.getDocument().getLength());
					}
				}
			}
		}.execute();
		
		if(type.equals("meterpreter"))
			inputField.setText("help");
		outputArea.setFont(new Font("Monospaced", outputArea.getFont().getStyle(), 12));
		checkPrompt(session);
	}
	/** Sets the prompt if provided */
	private void checkPrompt(Map o) {
		try{
			Object pobj = o.get("prompt");
			if (pobj != null)
				prompt = new String(Base64.decode(pobj.toString()));
			promptLabel.setText(prompt);
		}catch (MsfException mex){//bad prompt: do nothing
		}
	}
	/** This method is called from within the constructor to
	 * initialize the form.
	 * WARNING: Do NOT modify this code. The content of this method is
	 * always regenerated by the Form Editor.
	 */
	@SuppressWarnings("unchecked")
    // <editor-fold defaultstate="collapsed" desc="Generated Code">//GEN-BEGIN:initComponents
    private void initComponents() {

        outputScrollPane = new javax.swing.JScrollPane();
        outputArea = new javax.swing.JTextArea();
        inputField = new javax.swing.JTextField();
        submitButton = new javax.swing.JButton();
        promptLabel = new javax.swing.JLabel();

        addWindowListener(new java.awt.event.WindowAdapter() {
            public void windowClosed(java.awt.event.WindowEvent evt) {
                formWindowClosed(evt);
            }
            public void windowOpened(java.awt.event.WindowEvent evt) {
                formWindowOpened(evt);
            }
        });

        outputScrollPane.setAutoscrolls(true);
        outputScrollPane.setName("outputScrollPane"); // NOI18N

        outputArea.setColumns(20);
        outputArea.setEditable(false);
        outputArea.setRows(5);
        outputArea.setName("outputArea"); // NOI18N
        outputScrollPane.setViewportView(outputArea);

        org.jdesktop.application.ResourceMap resourceMap = org.jdesktop.application.Application.getInstance(msfgui.MsfguiApp.class).getContext().getResourceMap(InteractWindow.class);
        inputField.setText(resourceMap.getString("inputField.text")); // NOI18N
        inputField.setName("inputField"); // NOI18N
        inputField.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                inputFieldActionPerformed(evt);
            }
        });
        inputField.addKeyListener(new java.awt.event.KeyAdapter() {
            public void keyPressed(java.awt.event.KeyEvent evt) {
                inputFieldKeyPressed(evt);
            }
        });

        submitButton.setText(resourceMap.getString("submitButton.text")); // NOI18N
        submitButton.setName("submitButton"); // NOI18N
        submitButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                submitButtonActionPerformed(evt);
            }
        });

        promptLabel.setText(resourceMap.getString("promptLabel.text")); // NOI18N
        promptLabel.setName("promptLabel"); // NOI18N

        javax.swing.GroupLayout layout = new javax.swing.GroupLayout(getContentPane());
        getContentPane().setLayout(layout);
        layout.setHorizontalGroup(
            layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGroup(layout.createSequentialGroup()
                .addContainerGap()
                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addGroup(javax.swing.GroupLayout.Alignment.TRAILING, layout.createSequentialGroup()
                        .addComponent(promptLabel)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(inputField, javax.swing.GroupLayout.DEFAULT_SIZE, 628, Short.MAX_VALUE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(submitButton))
                    .addComponent(outputScrollPane, javax.swing.GroupLayout.DEFAULT_SIZE, 737, Short.MAX_VALUE))
                .addContainerGap())
        );
        layout.setVerticalGroup(
            layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGroup(javax.swing.GroupLayout.Alignment.TRAILING, layout.createSequentialGroup()
                .addContainerGap()
                .addComponent(outputScrollPane, javax.swing.GroupLayout.DEFAULT_SIZE, 533, Short.MAX_VALUE)
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                    .addComponent(inputField, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                    .addComponent(submitButton)
                    .addComponent(promptLabel))
                .addContainerGap())
        );

        pack();
    }// </editor-fold>//GEN-END:initComponents

	private void inputFieldActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_inputFieldActionPerformed
		try {
			String command = inputField.getText();
			commands.add(command);
			String data = Base64.encode((command+"\n").getBytes());
			rpcConn.execute(cmdPrefix+"write", new Object[]{session.get("id"),data});
			outputArea.append(prompt+command+"\n");
			outputArea.setCaretPosition(outputArea.getDocument().getLength());
			inputField.setText("");
			currentCommand = 0;
		} catch (MsfException ex) {
			JOptionPane.showMessageDialog(null, ex);
		}
	}//GEN-LAST:event_inputFieldActionPerformed

	private void submitButtonActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_submitButtonActionPerformed
		inputFieldActionPerformed(evt);
	}//GEN-LAST:event_submitButtonActionPerformed

	private void formWindowClosed(java.awt.event.WindowEvent evt) {//GEN-FIRST:event_formWindowClosed
		timerCommand.setCharAt(0, STOP_POLLING);
	}//GEN-LAST:event_formWindowClosed

	private void inputFieldKeyPressed(java.awt.event.KeyEvent evt) {//GEN-FIRST:event_inputFieldKeyPressed
		if(evt.getKeyCode() == KeyEvent.VK_UP){
			currentCommand = (currentCommand - 1 + commands.size()) % commands.size();
			inputField.setText(commands.get(currentCommand).toString());
		}else if(evt.getKeyCode() == KeyEvent.VK_DOWN){
			currentCommand = (currentCommand + 1) % commands.size();
			inputField.setText(commands.get(currentCommand).toString());
		}
	}//GEN-LAST:event_inputFieldKeyPressed

	private void formWindowOpened(java.awt.event.WindowEvent evt) {//GEN-FIRST:event_formWindowOpened
		inputField.requestFocusInWindow();
	}//GEN-LAST:event_formWindowOpened

    // Variables declaration - do not modify//GEN-BEGIN:variables
    private javax.swing.JTextField inputField;
    private javax.swing.JTextArea outputArea;
    private javax.swing.JScrollPane outputScrollPane;
    private javax.swing.JLabel promptLabel;
    private javax.swing.JButton submitButton;
    // End of variables declaration//GEN-END:variables
}
