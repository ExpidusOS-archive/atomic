pub fn ltr(offset: u16) void {
    asm volatile ("ltr %%ax"
        :
        : [offset] "{ax}" (offset),
    );
}

pub fn lidt(idt_ptr: *const idt.IdtPtr) void {
    asm volatile ("lidt (%%eax)"
        :
        : [idt_ptr] "{eax}" (idt_ptr),
    );
}
