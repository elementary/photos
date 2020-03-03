/*
* Copyright (c) 2009-2013 Yorba Foundation
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

public class BackgroundJobBatch : SortedList<BackgroundJob> {
    public BackgroundJobBatch () {
        base (BackgroundJob.priority_comparator);
    }
}

// Workers wraps some of ThreadPool's oddities up into an interface that emphasizes BackgroundJobs.
public class Workers {
    public const int UNLIMITED_THREADS = -1;

    private ThreadPool<void *> thread_pool;
    private AsyncQueue<BackgroundJob> queue = new AsyncQueue<BackgroundJob> ();
    private EventSemaphore empty_event = new EventSemaphore ();
    private int enqueued = 0;

    public Workers (int max_threads, bool exclusive) {
        if (max_threads <= 0 && max_threads != UNLIMITED_THREADS)
            max_threads = 1;

        // event starts as set because queue is empty
        empty_event.notify ();

        try {
            thread_pool = new ThreadPool<void *>.with_owned_data (thread_start, max_threads, exclusive);
        } catch (ThreadError err) {
            error ("Unable to create thread pool: %s", err.message);
        }
    }

    public static int threads_per_cpu (int per = 1, int max = -1) requires (per > 0) ensures (result > 0) {
        int count = number_of_processors () * per;

        return (max < 0) ? count : count.clamp (0, max);
    }

    // This is useful when the intent is for the worker threads to use all the CPUs minus one for
    // the main/UI thread.  (No guarantees, of course.)
    public static int thread_per_cpu_minus_one () ensures (result > 0) {
        return (number_of_processors () - 1).clamp (1, int.MAX);
    }

    // Enqueues a BackgroundJob for work in a thread context.  BackgroundJob.execute () is called
    // within the thread's context, while its CompletionCallback is called within the Gtk event loop.
    public void enqueue (BackgroundJob job) {
        empty_event.reset ();

        lock (queue) {
            queue.push_sorted (job, BackgroundJob.priority_compare_func);
            enqueued++;
        }

        try {
            thread_pool.add (job);
        } catch (ThreadError err) {
            // error should only occur when a thread could not be created, in which case, the
            // BackgroundJob is queued up
            warning ("Unable to create worker thread: %s", err.message);
        }
    }

    public void enqueue_many (BackgroundJobBatch batch) {
        foreach (BackgroundJob job in batch)
            enqueue (job);
    }

    public void wait_for_empty_queue () {
        empty_event.wait ();
    }

    // Returns the number of BackgroundJobs on the queue, not including active jobs.
    public int get_pending_job_count () {
        lock (queue) {
            return enqueued;
        }
    }

    private void thread_start (void *ignored) {
        BackgroundJob? job;
        bool empty;
        lock (queue) {
            job = queue.try_pop ();
            assert (job != null);

            assert (enqueued > 0);
            empty = (--enqueued == 0);
        }

        if (!job.is_cancelled ())
            job.execute ();

        job.internal_notify_completion ();

        if (empty)
            empty_event.notify ();
    }
}
