//! MIDI preview for the Output screen: list the system's MIDI output ports
//! and play a set of notes to one of them.
//!
//! Playback lives here rather than in the engine because it is a GUI
//! concern: the engine only reports the notes (its JSON `playback` field),
//! and nothing about ports or playing ends up in the structure formula.
//! `midir` talks to CoreMIDI, ALSA or WinMM directly - the Rust counterpart
//! of RtMidi, without a C++ build step.
//!
//! One playback at a time: starting a new one stops the previous one first.
//! Each runs on its own thread, which owns the port connection, sends the
//! notes on time, and on stop turns off whatever is still sounding.

use midir::{MidiOutput, MidiOutputConnection};
use serde::Deserialize;
use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{mpsc, Arc, Mutex};
use std::thread::JoinHandle;
use std::time::{Duration, Instant};

const CLIENT_NAME: &str = "Projekt 2";

/// How long the playback thread sleeps at most between checks of the stop
/// flag, so stopping (or starting another playback) is never noticeably late.
const POLL: Duration = Duration::from_millis(5);

/// One note as the GUI sends it: start and duration in seconds, MIDI note
/// number, velocity, channel (0-15).
#[derive(Deserialize)]
pub struct Note(f64, f64, u8, u8, u8);

struct Playback {
    stop: Arc<AtomicBool>,
    thread: JoinHandle<()>,
}

static CURRENT: Mutex<Option<Playback>> = Mutex::new(None);

fn stop_current() {
    let previous = CURRENT.lock().unwrap_or_else(|e| e.into_inner()).take();
    if let Some(p) = previous {
        p.stop.store(true, Ordering::SeqCst);
        let _ = p.thread.join();
    }
}

fn connect(port_name: &str) -> Result<MidiOutputConnection, String> {
    let output = MidiOutput::new(CLIENT_NAME).map_err(|e| e.to_string())?;
    let port = output
        .ports()
        .into_iter()
        .find(|p| output.port_name(p).is_ok_and(|n| n == port_name))
        .ok_or_else(|| format!("the MIDI port \u{201c}{port_name}\u{201d} is not available"))?;
    output
        .connect(&port, "preview")
        .map_err(|e| format!("could not open \u{201c}{port_name}\u{201d}: {e}"))
}

/// The names of the MIDI output ports currently available.
#[tauri::command]
pub fn midi_ports() -> Result<Vec<String>, String> {
    let output = MidiOutput::new(CLIENT_NAME).map_err(|e| e.to_string())?;
    Ok(output
        .ports()
        .iter()
        .filter_map(|p| output.port_name(p).ok())
        .collect())
}

/// Play `notes` to `port`, starting `from` seconds in. Notes that start
/// before `from` are skipped. Returns once the port is open (or with the
/// reason it couldn't be), while the notes play on in the background.
#[tauri::command]
pub fn midi_play(port: String, notes: Vec<Note>, from: f64) -> Result<(), String> {
    stop_current();

    let mut events: Vec<(f64, [u8; 3])> = Vec::with_capacity(notes.len() * 2);
    for Note(time, duration, key, velocity, channel) in notes {
        if time < from {
            continue;
        }
        let (key, channel) = (key & 0x7f, channel & 0x0f);
        events.push((time - from, [0x90 | channel, key, velocity.clamp(1, 127)]));
        events.push((time + duration - from, [0x80 | channel, key, 0]));
    }
    // By time; at the same time a note-off (0x8n) before a note-on (0x9n),
    // so a note repeated back to back is not cut off by its predecessor.
    events.sort_by(|a, b| a.0.total_cmp(&b.0).then(a.1[0].cmp(&b.1[0])));

    let stop = Arc::new(AtomicBool::new(false));
    let stop_flag = Arc::clone(&stop);
    let (ready_tx, ready_rx) = mpsc::channel();

    let thread = std::thread::spawn(move || {
        let mut connection = match connect(&port) {
            Ok(c) => {
                let _ = ready_tx.send(Ok(()));
                c
            }
            Err(e) => {
                let _ = ready_tx.send(Err(e));
                return;
            }
        };

        // (status, key) -> how many of that note are sounding, so stopping
        // halfway can switch off exactly those.
        let mut sounding: HashMap<(u8, u8), u32> = HashMap::new();
        let start = Instant::now();
        'events: for (time, message) in events {
            let due = start + Duration::from_secs_f64(time.max(0.0));
            loop {
                if stop_flag.load(Ordering::SeqCst) {
                    break 'events;
                }
                let now = Instant::now();
                if now >= due {
                    break;
                }
                std::thread::sleep((due - now).min(POLL));
            }
            let _ = connection.send(&message);
            let key = (message[0] & 0x0f, message[1]);
            if message[0] & 0xf0 == 0x90 {
                *sounding.entry(key).or_insert(0) += 1;
            } else if let Some(n) = sounding.get_mut(&key) {
                *n = n.saturating_sub(1);
            }
        }

        for ((channel, key), count) in sounding {
            if count > 0 {
                let _ = connection.send(&[0x80 | channel, key, 0]);
            }
        }
        connection.close();
    });

    match ready_rx.recv() {
        Ok(Ok(())) => {
            *CURRENT.lock().unwrap_or_else(|e| e.into_inner()) = Some(Playback { stop, thread });
            Ok(())
        }
        Ok(Err(e)) => {
            let _ = thread.join();
            Err(e)
        }
        Err(_) => Err("the MIDI playback thread stopped unexpectedly".to_string()),
    }
}

/// Stop the current playback, if any, switching off every sounding note.
#[tauri::command]
pub fn midi_stop() {
    stop_current();
}
