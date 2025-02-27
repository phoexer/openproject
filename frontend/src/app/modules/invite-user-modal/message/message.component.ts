import {
  Component,
  OnInit,
  Input,
  EventEmitter,
  Output,
  ElementRef,
  ViewChild,
} from '@angular/core';
import {
  FormControl,
  FormGroup,
} from '@angular/forms';
import {CdkTextareaAutosize} from '@angular/cdk/text-field';
import {I18nService} from "core-app/modules/common/i18n/i18n.service";
import {HalResource} from 'core-app/modules/hal/resources/hal-resource';
import {ProjectResource} from 'core-app/modules/hal/resources/project-resource';
import {PrincipalType} from '../invite-user.component';

@Component({
  selector: 'op-ium-message',
  templateUrl: './message.component.html',
  styleUrls: ['./message.component.sass'],
})
export class MessageComponent implements OnInit {
  @Input() type:PrincipalType;
  @Input() project:ProjectResource;
  @Input() principal:HalResource;
  @Input() message:string = '';

  @Output() close = new EventEmitter<void>();
  @Output() back = new EventEmitter<void>();
  @Output() save = new EventEmitter<{message:string}>();

  @ViewChild('input') input: ElementRef;
  @ViewChild('autosize') autosize: CdkTextareaAutosize;

  public text = {
    title: () => this.I18n.t('js.invite_user_modal.title.invite_principal_to_project', {
      principal: this.principal?.name,
      project: this.project?.name,
    }),
    label: this.I18n.t('js.invite_user_modal.message.label'),
    description: () => this.I18n.t('js.invite_user_modal.message.description', {
      principal: this.principal?.name,
    }),
    backButton: this.I18n.t('js.invite_user_modal.back'),
    nextButton: this.I18n.t('js.invite_user_modal.message.next_button'),
  };

  messageForm = new FormGroup({
    message: new FormControl(''),
  });

  get messageControl() { return this.messageForm.get('message'); }

  constructor(
    readonly I18n:I18nService,
    readonly elementRef:ElementRef,
  ) {}

  ngOnInit() {
    this.messageControl?.setValue(this.message);
  }

  ngAfterViewInit() {
    this.input.nativeElement.focus();
    this.autosize.resizeToFitContent(true);
  }

  onSubmit($e:Event) {
    $e.preventDefault();
    if (this.messageForm.invalid) {
      this.messageForm.markAsDirty();
      return;
    }

    this.save.emit({ message: this.messageControl?.value });
  }
}
